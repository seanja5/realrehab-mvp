-- Ultra-permissive fix: Create a policy that should definitely work
-- We'll make it very simple and permissive to get it working first

BEGIN;

-- Drop all existing policies
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;
DROP POLICY IF EXISTS device_assignments_insert_postgres ON telemetry.device_assignments;

-- Check if RLS is even the issue - let's see what happens if we make it super permissive
-- Create a policy that allows everything from postgres role
CREATE POLICY device_assignments_postgres_all
  ON telemetry.device_assignments
  FOR ALL
  TO postgres
  USING (true)
  WITH CHECK (true);

-- Also create the main policy for other roles
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- Allow postgres (should be caught by the policy above, but just in case)
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- Allow postgres
    current_user = 'postgres'::name
    -- Allow patients to insert their own
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
    )
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
  );

-- Verify policies were created
DO $$
DECLARE
  v_policy_count int;
BEGIN
  SELECT COUNT(*) INTO v_policy_count
  FROM pg_policy
  WHERE polrelid = 'telemetry.device_assignments'::regclass;
  
  RAISE NOTICE 'Total policies on device_assignments: %', v_policy_count;
  
  IF v_policy_count = 0 THEN
    RAISE EXCEPTION 'No policies were created!';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

