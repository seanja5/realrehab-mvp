BEGIN;

ALTER TABLE accounts.pt_profiles ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies on pt_profiles
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON accounts.pt_profiles;', r.policyname);
  END LOOP;
END $$;

-- Recreate minimal, non-recursive owner policies

-- SELECT: row visible only if this row belongs to the logged-in user
CREATE POLICY pt_profiles_select_owner
ON accounts.pt_profiles
FOR SELECT
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- INSERT: allowed only if NEW.profile_id belongs to the current user
CREATE POLICY pt_profiles_insert_owner
ON accounts.pt_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- UPDATE: allowed only by the owner (and must remain owned after update)
CREATE POLICY pt_profiles_update_owner
ON accounts.pt_profiles
FOR UPDATE
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
)
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

NOTIFY pgrst, 'reload schema';

COMMIT;

