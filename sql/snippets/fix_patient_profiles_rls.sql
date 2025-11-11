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

-- Create SECURITY DEFINER functions to avoid RLS recursion

-- Check if current user is a PT (by checking role in profiles)
-- This avoids querying pt_profiles which might have RLS issues
CREATE OR REPLACE FUNCTION accounts.is_current_user_pt()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.profiles
    WHERE user_id = auth.uid()
    AND role = 'pt'
  );
$$;

-- Check if a patient_profile_id is mapped to the current PT
CREATE OR REPLACE FUNCTION accounts.is_patient_mapped_to_current_pt(patient_profile_id_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_current_user_pt() TO authenticated;
GRANT EXECUTE ON FUNCTION accounts.is_patient_mapped_to_current_pt(UUID) TO authenticated;

-- Recreate minimal, non-recursive owner policies

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
  -- PT can see patients mapped to them (using SECURITY DEFINER function to avoid recursion)
  accounts.is_patient_mapped_to_current_pt(id)
);

-- INSERT: Allow PTs to create placeholder patients (profile_id can be NULL)
-- Also allow patients to create their own profile
-- Use SECURITY DEFINER function to check role (bypasses RLS if needed)
CREATE POLICY patient_profiles_insert_pt_or_self
ON accounts.patient_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  -- PT can insert placeholder patients (profile_id is NULL)
  (
    profile_id IS NULL
    AND accounts.is_current_user_pt()
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
  -- PT can update patients mapped to them (using SECURITY DEFINER function to avoid recursion)
  accounts.is_patient_mapped_to_current_pt(id)
)
WITH CHECK (
  -- Same conditions for WITH CHECK
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  accounts.is_patient_mapped_to_current_pt(id)
);

-- DELETE: Only patients can delete their own profile (PTs should use pt_patient_map deletion)
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

