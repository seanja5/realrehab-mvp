-- Fix RLS Policy for device_assignments to allow patients and RPC functions to create assignments
-- This allows patients to create device assignments when calibrating devices
-- Also allows SECURITY DEFINER functions (running as postgres/admin) to insert
-- 
-- REVERSIBLE: You can revert by dropping and recreating the original policy

BEGIN;

-- Drop the existing policy
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create a new policy that:
-- 1. Allows admins and postgres role (for SECURITY DEFINER functions)
-- 2. Allows PTs to manage assignments for their patients
-- 3. Allows patients to insert their own device assignments
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    accounts.is_admin()
    OR current_user = 'postgres'  -- Allow postgres role (SECURITY DEFINER functions)
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- Allow admins
    accounts.is_admin()
    -- Allow postgres role (SECURITY DEFINER functions run as postgres)
    OR current_user = 'postgres'
    -- Allow PTs to create assignments for their patients
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
    -- Allow patients to create their own device assignments
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
      AND (
        -- pt_profile_id can be NULL (patient not linked to PT yet)
        telemetry.device_assignments.pt_profile_id IS NULL
        -- OR pt_profile_id matches their linked PT
        OR EXISTS (
          SELECT 1
          FROM accounts.pt_patient_map ptm
          WHERE ptm.patient_profile_id = accounts.current_patient_profile_id()
            AND ptm.pt_profile_id = telemetry.device_assignments.pt_profile_id
        )
      )
    )
  );

-- Verify the policy was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'telemetry'
      AND tablename = 'device_assignments'
      AND policyname = 'device_assignments_access'
  ) THEN
    RAISE EXCEPTION 'Policy device_assignments_access was not created';
  END IF;
  
  RAISE NOTICE 'Policy device_assignments_access updated successfully';
END $$;

COMMIT;

-- REVERSAL SCRIPT (to revert to original policy):
-- BEGIN;
-- DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;
-- CREATE POLICY device_assignments_access
--   ON telemetry.device_assignments
--   FOR ALL
--   USING (
--     accounts.is_admin()
--     OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
--     OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
--   )
--   WITH CHECK (
--     accounts.is_admin()
--     OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
--     OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
--   );
-- COMMIT;

