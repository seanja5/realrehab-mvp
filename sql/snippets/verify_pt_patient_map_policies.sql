-- Verification query - check if pt_patient_map policies are correctly configured
-- This does NOT make changes, only verifies the current state

-- Check if is_patient_owned function exists and is correctly defined
SELECT 
    'is_patient_owned function exists' as check_name,
    EXISTS (
        SELECT 1
        FROM pg_proc p
        INNER JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'accounts'
          AND p.proname = 'is_patient_owned'
    ) as result;

-- Check pt_patient_map SELECT policy
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
  AND cmd = 'SELECT';

-- Check if is_patient_owned function works correctly
-- It should return TRUE for patients after they sign up (when profile_id is set)
-- Note: This is a verification query - it will show the function definition
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
INNER JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'accounts'
  AND p.proname = 'is_patient_owned';

