-- Alternative approach: Since RLS policy isn't working even with postgres check,
-- let's try granting explicit INSERT permission to the function or using a different method
-- 
-- Actually, wait - let me try one more thing: maybe we need to check if RLS is even the issue
-- or if it's a different permission problem

BEGIN;

-- First, let's check if the table has any other constraints or issues
DO $$
DECLARE
  v_rls_enabled boolean;
  v_policy_count int;
BEGIN
  -- Check if RLS is enabled
  SELECT rowsecurity INTO v_rls_enabled
  FROM pg_tables
  WHERE schemaname = 'telemetry'
    AND tablename = 'device_assignments';
  
  RAISE NOTICE 'RLS enabled on device_assignments: %', v_rls_enabled;
  
  -- Count policies
  SELECT COUNT(*) INTO v_policy_count
  FROM pg_policy
  WHERE polrelid = 'telemetry.device_assignments'::regclass;
  
  RAISE NOTICE 'Number of policies on device_assignments: %', v_policy_count;
END $$;

-- Try a completely different approach: Create a separate, simpler policy just for inserts
-- that explicitly allows postgres
DROP POLICY IF EXISTS device_assignments_insert_postgres ON telemetry.device_assignments;

CREATE POLICY device_assignments_insert_postgres
  ON telemetry.device_assignments
  FOR INSERT
  TO postgres
  WITH CHECK (true);  -- Allow all inserts from postgres role

-- Also update the main policy to be more explicit
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- Try multiple ways to check for postgres
    (current_user::text) = 'postgres'
    OR (session_user::text) = 'postgres'
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- For inserts, be even more explicit
    (current_user::text) = 'postgres'
    OR (session_user::text) = 'postgres'
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

NOTIFY pgrst, 'reload schema';

COMMIT;

