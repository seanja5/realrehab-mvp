-- Simple fix: Make the RLS policy explicitly allow postgres role for inserts
-- The issue is that WITH CHECK clause is blocking inserts even though USING allows SELECT

BEGIN;

-- Drop existing policy
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create a new policy with explicit postgres check FIRST in both clauses
-- The key is to put postgres check FIRST so it's evaluated before other conditions
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- CRITICAL: Check postgres FIRST - this must be the first condition
    (current_user::text = 'postgres')
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- CRITICAL: Check postgres FIRST - this must be the first condition
    -- This is what allows the SECURITY DEFINER function to insert
    (current_user::text = 'postgres')
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

-- Verify the policy
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'telemetry'
      AND tablename = 'device_assignments'
      AND policyname = 'device_assignments_access'
  ) THEN
    RAISE EXCEPTION 'Policy was not created';
  END IF;
  
  RAISE NOTICE 'Policy device_assignments_access created with postgres check';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

