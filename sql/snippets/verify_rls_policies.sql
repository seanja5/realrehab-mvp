-- Verify RLS policies are set up correctly
-- Run this after running the migration SQLs to confirm everything is working

-- Check patient_profiles policies
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'patient_profiles'
ORDER BY cmd, policyname;

-- Check pt_patient_map policies
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
ORDER BY cmd, policyname;

-- Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'accounts'
  AND tablename IN ('patient_profiles', 'pt_patient_map');

