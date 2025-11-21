-- Check table permissions and constraints
-- This will help us see if there are any other issues

-- Check table owner and permissions
SELECT 
  schemaname,
  tablename,
  tableowner,
  rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'telemetry'
  AND tablename = 'device_assignments';

-- Check all policies
SELECT 
  polname as "Policy Name",
  polcmd as "Command",
  polroles::regrole[] as "Roles",
  pg_get_expr(polqual, polrelid) as "USING clause",
  pg_get_expr(polwithcheck, polrelid) as "WITH CHECK clause"
FROM pg_policy
WHERE polrelid = 'telemetry.device_assignments'::regclass;

-- Check column constraints (especially NOT NULL)
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'telemetry'
  AND table_name = 'device_assignments'
ORDER BY ordinal_position;

-- Check grants on the table
SELECT 
  grantee,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'telemetry'
  AND table_name = 'device_assignments';

