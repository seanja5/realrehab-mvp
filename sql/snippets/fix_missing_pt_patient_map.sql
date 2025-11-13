BEGIN;

-- This script helps diagnose and fix missing pt_patient_map rows
-- Run the diagnostic queries first to identify the issue

-- If pt_patient_map row is missing, you can manually create it
-- Replace the UUIDs with actual values from your database

-- Example: Create missing mapping (uncomment and update UUIDs)
/*
INSERT INTO accounts.pt_patient_map (patient_profile_id, pt_profile_id)
VALUES (
  '00869528-6CA2-414D-A8B6-7E80B7D37405',  -- patient_profile_id from patient_profiles.id
  'YOUR_PT_PROFILE_ID_HERE'                 -- pt_profile_id from pt_profiles.id
)
ON CONFLICT (patient_profile_id) DO NOTHING;
*/

-- Check if the INSERT policy allows PTs to insert
-- The policy should allow: accounts.is_pt_owned(pt_profile_id)
SELECT 
  policyname,
  cmd,
  with_check
FROM pg_policies
WHERE schemaname = 'accounts' 
  AND tablename = 'pt_patient_map'
  AND cmd = 'INSERT';

COMMIT;

