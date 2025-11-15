-- Comprehensive debug script to understand why DELETE is failing

-- 1. Check current user
SELECT 
    auth.uid() as current_user_id,
    auth.role() as current_role;

-- 2. Check if current user is a PT and get their pt_profile_id
SELECT 
    ptp.id as pt_profile_id,
    p.id as profile_id,
    p.user_id,
    p.role
FROM accounts.pt_profiles ptp
INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
WHERE p.user_id = auth.uid();

-- 3. Check all pt_patient_map rows for this PT
SELECT 
    ptm.id,
    ptm.pt_profile_id,
    ptm.patient_profile_id,
    -- Test if the policy would allow this
    EXISTS (
        SELECT 1
        FROM accounts.pt_profiles ptp2
        INNER JOIN accounts.profiles p2 ON ptp2.profile_id = p2.id
        WHERE ptp2.id = ptm.pt_profile_id
          AND p2.user_id = auth.uid()
    ) as policy_would_allow_delete
FROM accounts.pt_patient_map ptm
WHERE ptm.pt_profile_id IN (
    SELECT ptp.id
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE p.user_id = auth.uid()
);

-- 4. Check ALL policies on pt_patient_map (including any we might have missed)
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
ORDER BY policyname, cmd;

-- 5. Check if there are any DENY policies (which would override ALLOW)
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
  AND permissive = 'RESTRICTIVE';

