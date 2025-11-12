BEGIN;

-- Enable RLS on pt_profiles if not already enabled
ALTER TABLE accounts.pt_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing SELECT policies if they exist (we'll recreate a comprehensive one)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_profiles'
      AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON accounts.pt_profiles;', r.policyname);
  END LOOP;
END $$;

-- Create comprehensive SELECT policy that allows:
-- 1. PTs to see their own profile
-- 2. Patients to see PTs they're mapped to via pt_patient_map
CREATE POLICY pt_profiles_select_owner_or_mapped
ON accounts.pt_profiles
FOR SELECT
TO authenticated
USING (
  -- PT can see their own profile
  EXISTS (
    SELECT 1
    FROM accounts.profiles p
    WHERE p.id = pt_profiles.profile_id
      AND p.user_id = auth.uid()
  )
  OR
  -- Patient can see PTs they're mapped to
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.patient_profiles pat ON ptm.patient_profile_id = pat.id
    INNER JOIN accounts.profiles p ON pat.profile_id = p.id
    WHERE ptm.pt_profile_id = pt_profiles.id
      AND p.user_id = auth.uid()
  )
);

NOTIFY pgrst, 'reload schema';

COMMIT;

