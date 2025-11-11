-- Diagnostic query to check what's happening
-- Run this to see if the user can read their own profile and role

BEGIN;

-- Check if current user can see their profile
SELECT 
  id,
  user_id,
  email,
  role,
  first_name,
  last_name
FROM accounts.profiles
WHERE user_id = auth.uid();

-- Check if there are any RLS policies blocking reads on profiles
SELECT 
  policyname,
  cmd,
  roles,
  qual AS using_expr
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'profiles'
  AND cmd = 'SELECT';

COMMIT;

