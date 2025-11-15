-- Diagnostic script to check the current state of pt_patient_map DELETE policy
-- Run this in Supabase SQL Editor to see what's currently configured

-- 1. Check if the is_pt_owned function exists
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    p.prosecdef as is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'accounts'
  AND p.proname = 'is_pt_owned';

-- 2. Check all policies on pt_patient_map
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
ORDER BY policyname;

-- 3. Check if RLS is enabled on the table
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map';

-- 4. Test the is_pt_owned function (replace with your actual pt_profile_id)
-- SELECT accounts.is_pt_owned('YOUR_PT_PROFILE_ID_HERE'::uuid);

