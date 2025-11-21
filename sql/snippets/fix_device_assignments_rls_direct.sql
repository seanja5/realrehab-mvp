-- Direct fix: Since we confirmed the function runs as 'postgres',
-- we just need to make sure the RLS policy explicitly allows it
-- This is the simplest possible fix

BEGIN;

-- Drop existing policy
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create policy with explicit postgres check
-- Since test_current_user() confirmed we're running as 'postgres',
-- this should work
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- This is the critical part - must allow postgres for inserts
    current_user = 'postgres'::name
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

-- Verify
DO $$
DECLARE
  policy_count int;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'telemetry'
    AND tablename = 'device_assignments'
    AND policyname = 'device_assignments_access';
  
  IF policy_count = 0 THEN
    RAISE EXCEPTION 'Policy was not created';
  END IF;
  
  RAISE NOTICE 'Policy created successfully. Policy count: %', policy_count;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

