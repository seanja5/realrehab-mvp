-- Quick check: What policies exist on pt_patient_map?
SELECT 
    policyname,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
ORDER BY policyname, cmd;

-- Check if is_pt_owned function exists
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'accounts'
  AND p.proname = 'is_pt_owned';

