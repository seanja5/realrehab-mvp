-- Test query to verify access code lookup will work
-- This simulates what PatientService.findPatientByAccessCode does

-- 1. Check all placeholders (profile_id IS NULL) with access codes
-- These are the patients that PTs have added but haven't signed up yet
SELECT 
  id,
  profile_id,
  access_code,
  first_name,
  last_name,
  date_of_birth,
  gender,
  created_at
FROM accounts.patient_profiles
WHERE profile_id IS NULL
  AND access_code IS NOT NULL
ORDER BY created_at DESC;

-- 2. Verify the pt_patient_map exists for these placeholders
-- This shows which PT each placeholder is linked to
SELECT 
  pp.id as patient_profile_id,
  pp.access_code,
  pp.first_name,
  pp.last_name,
  ptm.pt_profile_id,
  pt.first_name as pt_first_name,
  pt.last_name as pt_last_name
FROM accounts.patient_profiles pp
LEFT JOIN accounts.pt_patient_map ptm ON pp.id = ptm.patient_profile_id
LEFT JOIN accounts.pt_profiles pt ON ptm.pt_profile_id = pt.id
WHERE pp.profile_id IS NULL
  AND pp.access_code IS NOT NULL
ORDER BY pp.created_at DESC;

-- 3. Test if you can query a specific placeholder by access code
-- Replace 'YOUR_ACCESS_CODE' with an actual access code from query #1
-- This simulates what happens during patient signup
SELECT 
  id,
  profile_id,
  access_code,
  first_name,
  last_name
FROM accounts.patient_profiles
WHERE access_code = 'YOUR_ACCESS_CODE'  -- Replace with actual code
  AND profile_id IS NULL
LIMIT 1;

-- 4. Check RLS policies to verify the fix was applied
SELECT 
  policyname,
  cmd,
  qual as using_clause
FROM pg_policies
WHERE schemaname = 'accounts' 
  AND tablename = 'patient_profiles'
  AND cmd = 'SELECT';

