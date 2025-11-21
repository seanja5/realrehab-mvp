-- Diagnostic script to check RLS policy and RPC function setup
-- Run this to see what's blocking the device assignment creation

-- Check current user context
SELECT 
  current_user as "Current User",
  session_user as "Session User",
  current_setting('role') as "Current Role";

-- Check if RPC function exists and its owner
SELECT 
  p.proname as "Function Name",
  n.nspname as "Schema",
  pg_get_userbyid(p.proowner) as "Owner",
  p.prosecdef as "Security Definer",
  pg_get_functiondef(p.oid) LIKE '%SECURITY DEFINER%' as "Has Security Definer"
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname = 'get_or_create_device_assignment';

-- Check RLS policy on device_assignments
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual as "USING clause",
  with_check as "WITH CHECK clause"
FROM pg_policies
WHERE schemaname = 'telemetry'
  AND tablename = 'device_assignments';

-- Check if RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'telemetry'
  AND tablename = 'device_assignments';

-- Test if we can query device_assignments (this will show RLS in action)
-- Note: This will only work if you're logged in as a patient
SELECT COUNT(*) as "Visible Device Assignments"
FROM telemetry.device_assignments;

