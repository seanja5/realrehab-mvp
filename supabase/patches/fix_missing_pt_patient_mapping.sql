-- Fix missing PT-Patient mapping
-- This creates the mapping that should have been created when the patient was added

BEGIN;

-- First, let's see what we're working with
-- Get the current PT's profile and pt_profile_id
SELECT 
  'Your PT Profile' AS info,
  p.user_id,
  p.id AS profile_id,
  pt.id AS pt_profile_id
FROM accounts.profiles p
JOIN accounts.pt_profiles pt ON pt.profile_id = p.id
WHERE p.user_id = auth.uid()
  AND p.role = 'pt';

-- Get the patient profile info
SELECT 
  'Patient Profile' AS info,
  pp.id AS patient_profile_id,
  pp.first_name,
  pp.last_name,
  pp.profile_id
FROM accounts.patient_profiles pp
WHERE pp.id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid;

-- Check if mapping already exists (should be empty based on your query)
SELECT 
  'Existing Mapping' AS info,
  m.pt_profile_id,
  m.patient_profile_id
FROM accounts.pt_patient_map m
WHERE m.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid;

-- Create the mapping
-- Replace 'YOUR_PT_PROFILE_ID_HERE' with the pt_profile_id from the first query above
-- Or use this dynamic version that gets your PT profile automatically:
INSERT INTO accounts.pt_patient_map (pt_profile_id, patient_profile_id)
SELECT 
  pt.id AS pt_profile_id,
  'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid AS patient_profile_id
FROM accounts.profiles p
JOIN accounts.pt_profiles pt ON pt.profile_id = p.id
WHERE p.user_id = auth.uid()
  AND p.role = 'pt'
  AND NOT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map m
    WHERE m.pt_profile_id = pt.id
      AND m.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid
  );

-- Verify the mapping was created
SELECT 
  'New Mapping Created' AS info,
  m.pt_profile_id,
  m.patient_profile_id,
  'SUCCESS' AS status
FROM accounts.pt_patient_map m
JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
JOIN accounts.profiles p ON p.id = pt.profile_id
WHERE m.patient_profile_id = 'F4054889-BDCA-45A0-B30C-9D767B386AF6'::uuid
  AND p.user_id = auth.uid();

COMMIT;

