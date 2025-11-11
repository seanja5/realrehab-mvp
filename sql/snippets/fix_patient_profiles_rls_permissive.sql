BEGIN;

ALTER TABLE accounts.patient_profiles ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies on patient_profiles
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

-- TEMPORARY PERMISSIVE POLICY FOR TESTING
-- This allows any authenticated user to insert with profile_id = NULL
-- We'll tighten this after confirming it works

-- SELECT: Allow users to see their own profile OR any profile with NULL profile_id
CREATE POLICY patient_profiles_select_test
ON accounts.patient_profiles
FOR SELECT
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR profile_id IS NULL
);

-- INSERT: PERMISSIVE - Allow any authenticated user to insert with profile_id = NULL
-- This is for testing - we'll add role check after confirming it works
CREATE POLICY patient_profiles_insert_test
ON accounts.patient_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  -- Allow inserting with NULL profile_id (placeholder patients)
  profile_id IS NULL
  OR
  -- Allow inserting own profile
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- UPDATE: Allow users to update their own profile
CREATE POLICY patient_profiles_update_test
ON accounts.patient_profiles
FOR UPDATE
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR profile_id IS NULL
)
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR profile_id IS NULL
);

-- DELETE: Only allow deleting own profile
CREATE POLICY patient_profiles_delete_test
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

