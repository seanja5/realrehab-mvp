-- Test script to diagnose why DELETE is failing
-- Replace YOUR_PT_PROFILE_ID with your actual pt_profile_id from session.ptProfileId

-- Step 1: Check what pt_profile_id the current user owns
SELECT 
    ptp.id as pt_profile_id,
    p.user_id,
    auth.uid() as current_auth_uid
FROM accounts.pt_profiles ptp
INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
WHERE p.user_id = auth.uid();

-- Step 2: Test if is_pt_owned works for your pt_profile_id
-- Replace YOUR_PT_PROFILE_ID with the id from Step 1
SELECT 
    accounts.is_pt_owned('YOUR_PT_PROFILE_ID_HERE'::uuid) as function_returns_true;

-- Step 3: Check if there are any pt_patient_map rows for your PT
SELECT 
    ptm.id,
    ptm.pt_profile_id,
    ptm.patient_profile_id,
    accounts.is_pt_owned(ptm.pt_profile_id) as should_be_allowed
FROM accounts.pt_patient_map ptm
WHERE ptm.pt_profile_id IN (
    SELECT ptp.id
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE p.user_id = auth.uid()
);

-- Step 4: Check the actual DELETE policy
SELECT 
    policyname,
    cmd,
    qual as using_clause,
    pg_get_expr(qual, 'accounts.pt_patient_map'::regclass) as using_expression
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
  AND cmd = 'DELETE';

