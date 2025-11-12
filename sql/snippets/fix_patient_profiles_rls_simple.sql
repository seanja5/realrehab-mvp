BEGIN;

ALTER TABLE accounts.patient_profiles ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies on patient_profiles
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'patient_profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON accounts.patient_profiles;', r.policyname);
  END LOOP;
END $$;

-- SELECT: Users can see their own patient profile OR PTs can see patients mapped to them
CREATE POLICY patient_profiles_select_owner
ON accounts.patient_profiles
FOR SELECT
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profiles.id
      AND p.user_id = auth.uid()
  )
);

-- INSERT: SIMPLEST POSSIBLE - Allow ANY authenticated user to insert if profile_id IS NULL
-- This is the absolute simplest policy - just check if the column is NULL
CREATE POLICY patient_profiles_insert_null
ON accounts.patient_profiles
FOR INSERT
TO authenticated
WITH CHECK (profile_id IS NULL);

-- INSERT: Allow patients to insert their own profile
CREATE POLICY patient_profiles_insert_own
ON accounts.patient_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- UPDATE: Allow updating from NULL to user's profile, or updating own profile
CREATE POLICY patient_profiles_update
ON accounts.patient_profiles
FOR UPDATE
TO authenticated
USING (
  profile_id IS NULL
  OR
  profile_id IN (SELECT id FROM accounts.profiles WHERE user_id = auth.uid())
  OR
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profiles.id
      AND p.user_id = auth.uid()
  )
)
WITH CHECK (
  profile_id IN (SELECT id FROM accounts.profiles WHERE user_id = auth.uid())
  OR
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profiles.id
      AND p.user_id = auth.uid()
  )
);

-- DELETE: Only patients can delete their own profile
CREATE POLICY patient_profiles_delete
ON accounts.patient_profiles
FOR DELETE
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

NOTIFY pgrst, 'reload schema';

COMMIT;
