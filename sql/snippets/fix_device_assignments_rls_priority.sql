-- Fix: Put postgres check FIRST in the policy evaluation
-- PostgreSQL evaluates OR conditions left-to-right, so order matters
-- If postgres check is first and true, it short-circuits and allows the operation

BEGIN;

-- Drop existing policy
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create policy with postgres check FIRST (most important!)
-- PostgreSQL will short-circuit the OR evaluation, so if postgres check passes,
-- it won't even evaluate the other conditions
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- FIRST: Check for postgres (SECURITY DEFINER functions)
    -- This must be first so it short-circuits the OR evaluation
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- CRITICAL: postgres check MUST be first here too
    -- This is what allows the RPC function to INSERT
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

-- Verify the policy was created and check its definition
DO $$
DECLARE
  v_policy_exists boolean;
  v_with_check text;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'telemetry'
      AND tablename = 'device_assignments'
      AND policyname = 'device_assignments_access'
  ) INTO v_policy_exists;
  
  IF NOT v_policy_exists THEN
    RAISE EXCEPTION 'Policy was not created';
  END IF;
  
  -- Get the WITH CHECK clause to verify postgres is first
  SELECT pg_get_expr(polwithcheck, polrelid)::text
  INTO v_with_check
  FROM pg_policy
  WHERE polrelid = 'telemetry.device_assignments'::regclass
    AND polname = 'device_assignments_access';
  
  IF v_with_check NOT LIKE '%current_user = ''postgres''%' THEN
    RAISE WARNING 'Policy created but postgres check may not be in WITH CHECK clause: %', v_with_check;
  ELSE
    RAISE NOTICE 'Policy created successfully with postgres check in WITH CHECK clause';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

