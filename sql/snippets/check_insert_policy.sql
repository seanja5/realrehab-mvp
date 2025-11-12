-- Check if the INSERT policy for patient_profiles exists and allows NULL profile_id
-- This is the critical policy that allows PTs to add patients

SELECT 
    policyname,
    cmd,
    CASE 
        WHEN with_check LIKE '%profile_id IS NULL%' THEN '✅ Allows NULL profile_id'
        ELSE '❌ Does NOT allow NULL profile_id'
    END as null_check_status,
    with_check
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'patient_profiles'
  AND cmd = 'INSERT'
ORDER BY policyname;

-- Also check total number of policies
SELECT 
    tablename,
    cmd,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename IN ('patient_profiles', 'pt_patient_map')
GROUP BY tablename, cmd
ORDER BY tablename, cmd;

