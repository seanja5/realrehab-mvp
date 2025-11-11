-- Diagnostic query to check why PT can't view rehab plans
-- Run this as the logged-in PT user (9C4B0035-290E-4D21-9FB5-49956030F3CB)

BEGIN;

-- 1) Check current user's PT profile
SELECT 
  'Current User PT Profile' AS check_type,
  p.user_id,
  p.id AS profile_id,
  p.role,
  pt.id AS pt_profile_id,
  pt.profile_id AS pt_profile_profile_id
FROM accounts.profiles p
LEFT JOIN accounts.pt_profiles pt ON pt.profile_id = p.id
WHERE p.user_id = auth.uid()
  AND p.role = 'pt';

-- 2) Check if patient exists and has a profile
SELECT 
  'Patient Profile Check' AS check_type,
  pp.id AS patient_profile_id,
  pp.profile_id,
  p.user_id AS patient_user_id,
  p.role AS patient_role
FROM accounts.patient_profiles pp
LEFT JOIN accounts.profiles p ON p.id = pp.profile_id
WHERE pp.id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid;

-- 3) Check pt_patient_map for this PT and patient
SELECT 
  'PT-Patient Mapping' AS check_type,
  m.pt_profile_id,
  m.patient_profile_id,
  pt.profile_id AS pt_profile_profile_id,
  p.user_id AS pt_user_id
FROM accounts.pt_patient_map m
JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
JOIN accounts.profiles p ON p.id = pt.profile_id
WHERE m.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid
  AND p.user_id = auth.uid();

-- 4) Check existing rehab plans for this patient
SELECT 
  'Existing Rehab Plans' AS check_type,
  rp.id AS plan_id,
  rp.pt_profile_id,
  rp.patient_profile_id,
  rp.category,
  rp.injury,
  rp.status,
  pt.profile_id AS plan_pt_profile_profile_id,
  p.user_id AS plan_pt_user_id
FROM accounts.rehab_plans rp
LEFT JOIN accounts.pt_profiles pt ON pt.id = rp.pt_profile_id
LEFT JOIN accounts.profiles p ON p.id = pt.profile_id
WHERE rp.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid;

-- 5) Test the helper functions directly
SELECT 
  'Helper Function Test - is_pt_owned' AS check_type,
  accounts.is_pt_owned(pt.id) AS is_pt_owned_result
FROM accounts.pt_profiles pt
JOIN accounts.profiles p ON p.id = pt.profile_id
WHERE p.user_id = auth.uid()
LIMIT 1;

SELECT 
  'Helper Function Test - is_patient_owned' AS check_type,
  accounts.is_patient_owned('F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid) AS is_patient_owned_result;

COMMIT;

