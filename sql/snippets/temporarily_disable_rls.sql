-- Temporarily disable RLS on device_assignments to test if that's the issue
-- WARNING: This removes security, but we'll re-enable it once we confirm it works

BEGIN;

-- Disable RLS on the table
ALTER TABLE telemetry.device_assignments DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
DO $$
DECLARE
  v_rls_enabled boolean;
BEGIN
  SELECT rowsecurity INTO v_rls_enabled
  FROM pg_tables
  WHERE schemaname = 'telemetry'
    AND tablename = 'device_assignments';
  
  IF v_rls_enabled THEN
    RAISE EXCEPTION 'RLS is still enabled on device_assignments';
  ELSE
    RAISE NOTICE 'RLS has been DISABLED on device_assignments - this is temporary for testing';
  END IF;
END $$;

COMMIT;

-- IMPORTANT: After testing, run the re-enable script to restore security
-- File: re_enable_rls_with_working_policy.sql

