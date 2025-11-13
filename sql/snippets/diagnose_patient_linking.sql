-- Diagnostic query to check patient linking status
-- Run this in Supabase SQL editor to diagnose linking issues

-- 1. Check if access_code function exists
SELECT 
  proname as function_name,
  pronamespace::regnamespace as schema_name
FROM pg_proc
WHERE proname = 'generate_unique_access_code';

-- 2. Check patient_profiles row
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
WHERE id = '00869528-6CA2-414D-A8B6-7E80B7D37405';

-- 3. Check if pt_patient_map row exists (bypassing RLS with service role if needed)
SELECT 
  id,
  patient_profile_id,
  pt_profile_id,
  created_at
FROM accounts.pt_patient_map
WHERE patient_profile_id = '00869528-6CA2-414D-A8B6-7E80B7D37405';

-- 4. Check all pt_patient_map rows for this PT (if you know the pt_profile_id)
-- Replace 'YOUR_PT_PROFILE_ID' with the actual PT's pt_profiles.id
SELECT 
  ptm.id,
  ptm.patient_profile_id,
  ptm.pt_profile_id,
  pp.first_name,
  pp.last_name,
  pp.access_code
FROM accounts.pt_patient_map ptm
LEFT JOIN accounts.patient_profiles pp ON ptm.patient_profile_id = pp.id
WHERE ptm.pt_profile_id = 'YOUR_PT_PROFILE_ID';  -- Replace with actual PT profile ID

-- 5. Check RLS policies on pt_patient_map
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'accounts' 
  AND tablename = 'pt_patient_map';

