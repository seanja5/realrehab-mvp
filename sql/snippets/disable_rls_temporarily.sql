-- TEMPORARY: Disable RLS on patient_profiles to test if insert works
-- WARNING: This is NOT secure - only use for testing!
-- After confirming insert works, re-enable RLS and apply proper policies

BEGIN;

-- Disable RLS temporarily
ALTER TABLE accounts.patient_profiles DISABLE ROW LEVEL SECURITY;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- After testing, run this to re-enable RLS:
-- ALTER TABLE accounts.patient_profiles ENABLE ROW LEVEL SECURITY;

