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

-- Create a SECURITY DEFINER function that truly bypasses RLS
-- This function will be owned by postgres/service_role and can read profiles without RLS
CREATE OR REPLACE FUNCTION accounts.check_user_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = accounts, public
AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- This query runs with DEFINER privileges, bypassing RLS
  SELECT role INTO user_role
  FROM accounts.profiles
  WHERE user_id = auth.uid()
  LIMIT 1;
  
  RETURN COALESCE(user_role, '');
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION accounts.check_user_role() TO authenticated;

-- SELECT: Users can see their own patient profile OR PTs can see patients mapped to them
CREATE POLICY patient_profiles_select_owner
ON accounts.patient_profiles
FOR SELECT
TO authenticated
USING (
  -- Patient can see their own profile
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  -- PT can see patients mapped to them via pt_patient_map
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profiles.id
      AND p.user_id = auth.uid()
  )
);

-- INSERT: Use SECURITY DEFINER function to check role (bypasses RLS)
CREATE POLICY patient_profiles_insert_pt_or_self
ON accounts.patient_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  -- PT can insert placeholder patients (profile_id is NULL)
  -- Use function to check role - this bypasses RLS on profiles
  (
    profile_id IS NULL
    AND accounts.check_user_role() = 'pt'
  )
  OR
  -- Patient can insert their own profile
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- UPDATE: Patients can update their own profile OR PTs can update patients mapped to them
CREATE POLICY patient_profiles_update_owner
ON accounts.patient_profiles
FOR UPDATE
TO authenticated
USING (
  -- Patient can update their own profile
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  -- PT can update patients mapped to them
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
  -- Same conditions for WITH CHECK
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

-- DELETE: Only patients can delete their own profile
CREATE POLICY patient_profiles_delete_owner
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

