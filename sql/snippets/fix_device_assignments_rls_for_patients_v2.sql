-- Fix RLS Policy for device_assignments to allow patients and RPC functions to create assignments
-- Version 2: More explicit postgres role check
-- This allows patients to create device assignments when calibrating devices
-- Also allows SECURITY DEFINER functions (running as postgres/admin) to insert
-- 
-- REVERSIBLE: You can revert by dropping and recreating the original policy

BEGIN;

-- Drop ALL existing policies on device_assignments to start fresh
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create a new policy that explicitly allows postgres role (for SECURITY DEFINER functions)
-- The key is to check current_user = 'postgres' FIRST in both USING and WITH CHECK
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- FIRST: Allow postgres role (SECURITY DEFINER functions run as postgres)
    -- This must be first to ensure RPC functions can bypass RLS
    current_user = 'postgres'
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- FIRST: Allow postgres role (SECURITY DEFINER functions run as postgres)
    -- This must be first to ensure RPC functions can bypass RLS
    current_user = 'postgres'
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
      AND (
        telemetry.device_assignments.pt_profile_id IS NULL
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
  
  RAISE NOTICE 'Policy device_assignments_access updated successfully with postgres role support';
END $$;

-- Also verify RLS is enabled on the table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_tables
    WHERE schemaname = 'telemetry'
      AND tablename = 'device_assignments'
      AND rowsecurity = true
  ) THEN
    RAISE WARNING 'RLS is not enabled on telemetry.device_assignments - enabling it now';
    ALTER TABLE telemetry.device_assignments ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

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

