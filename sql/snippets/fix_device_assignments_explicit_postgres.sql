-- Explicit postgres role policy - this should definitely work
-- Using TO postgres clause explicitly grants permission to the postgres role

BEGIN;

-- Drop all existing policies
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;
DROP POLICY IF EXISTS device_assignments_postgres_all ON telemetry.device_assignments;
DROP POLICY IF EXISTS device_assignments_insert_postgres ON telemetry.device_assignments;

-- Create an explicit policy for postgres role that allows everything
-- This uses the TO postgres clause which explicitly grants to the postgres role
CREATE POLICY device_assignments_postgres_all
  ON telemetry.device_assignments
  FOR ALL
  TO postgres
  USING (true)
  WITH CHECK (true);

-- Create the main policy for authenticated users
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  TO authenticated
  USING (
    accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    accounts.is_admin()
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
    )
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
  );

-- Verify
DO $$
DECLARE
  v_postgres_policy_exists boolean;
  v_main_policy_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'telemetry.device_assignments'::regclass
      AND polname = 'device_assignments_postgres_all'
  ) INTO v_postgres_policy_exists;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'telemetry.device_assignments'::regclass
      AND polname = 'device_assignments_access'
  ) INTO v_main_policy_exists;
  
  IF NOT v_postgres_policy_exists THEN
    RAISE EXCEPTION 'Postgres policy was not created';
  END IF;
  
  IF NOT v_main_policy_exists THEN
    RAISE EXCEPTION 'Main policy was not created';
  END IF;
  
  RAISE NOTICE 'Both policies created successfully';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

