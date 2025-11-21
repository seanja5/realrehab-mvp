-- Verify and Fix RLS Policy for device_assignments
-- This script checks the current state and ensures postgres role can bypass RLS
-- Run this if you're still getting "permission denied for table device_assignments"

BEGIN;

-- First, let's check what the current policy looks like
DO $$
DECLARE
  policy_exists boolean;
  policy_def text;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'telemetry'
      AND tablename = 'device_assignments'
      AND policyname = 'device_assignments_access'
  ) INTO policy_exists;
  
  IF policy_exists THEN
    SELECT pg_get_expr(polqual, polrelid)::text
    FROM pg_policy
    WHERE polrelid = 'telemetry.device_assignments'::regclass
      AND polname = 'device_assignments_access'
    INTO policy_def;
    
    RAISE NOTICE 'Current policy definition: %', policy_def;
  ELSE
    RAISE NOTICE 'No policy found - will create one';
  END IF;
END $$;

-- Drop and recreate the policy with explicit postgres check FIRST
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create policy with postgres check FIRST (most permissive)
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- CRITICAL: Check postgres FIRST - this allows SECURITY DEFINER functions to bypass RLS
    CURRENT_USER = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- CRITICAL: Check postgres FIRST - this allows SECURITY DEFINER functions to bypass RLS
    CURRENT_USER = 'postgres'::name
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

-- Verify the RPC function exists and is owned by postgres
DO $$
DECLARE
  func_owner text;
BEGIN
  SELECT pg_get_userbyid(p.proowner)::text
  INTO func_owner
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname = 'get_or_create_device_assignment';
  
  IF func_owner IS NULL THEN
    RAISE EXCEPTION 'RPC function get_or_create_device_assignment does not exist. Run create_get_or_create_device_assignment_rpc.sql first.';
  ELSIF func_owner != 'postgres' THEN
    RAISE WARNING 'RPC function is owned by % instead of postgres. This may cause RLS issues.', func_owner;
  ELSE
    RAISE NOTICE 'RPC function exists and is owned by postgres ✓';
  END IF;
END $$;

-- Verify RLS is enabled
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_tables
    WHERE schemaname = 'telemetry'
      AND tablename = 'device_assignments'
      AND rowsecurity = true
  ) THEN
    RAISE WARNING 'RLS is not enabled - enabling it now';
    ALTER TABLE telemetry.device_assignments ENABLE ROW LEVEL SECURITY;
  ELSE
    RAISE NOTICE 'RLS is enabled on telemetry.device_assignments ✓';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Test query to verify postgres can access (run as postgres user if possible)
-- SELECT current_user, CURRENT_USER;
-- This should return 'postgres' when run inside a SECURITY DEFINER function

