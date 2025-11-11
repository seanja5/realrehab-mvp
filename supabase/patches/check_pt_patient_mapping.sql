-- Check if the PT is properly mapped to the patient
-- Run this as the logged-in PT user

BEGIN;

-- 1) Get the current PT's profile and pt_profile_id
SELECT 
  'Your PT Profile' AS check_type,
  p.user_id,
  p.id AS profile_id,
  pt.id AS pt_profile_id
FROM accounts.profiles p
JOIN accounts.pt_profiles pt ON pt.profile_id = p.id
WHERE p.user_id = auth.uid()
  AND p.role = 'pt';

-- 2) Check if there's a mapping in pt_patient_map
SELECT 
  'PT-Patient Mapping Check' AS check_type,
  m.pt_profile_id,
  m.patient_profile_id,
  CASE 
    WHEN m.pt_profile_id IS NOT NULL THEN 'MAPPED'
    ELSE 'NOT MAPPED'
  END AS mapping_status
FROM accounts.pt_patient_map m
JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
JOIN accounts.profiles p ON p.id = pt.profile_id
WHERE m.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid
  AND p.user_id = auth.uid();

-- 3) Check ALL mappings for this patient (to see who IS mapped)
SELECT 
  'All Mappings for This Patient' AS check_type,
  m.pt_profile_id,
  m.patient_profile_id,
  pt.profile_id AS pt_profile_profile_id,
  p.user_id AS pt_user_id,
  p.email AS pt_email
FROM accounts.pt_patient_map m
JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
JOIN accounts.profiles p ON p.id = pt.profile_id
WHERE m.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid;

COMMIT;

