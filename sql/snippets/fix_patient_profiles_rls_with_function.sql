BEGIN;

ALTER TABLE accounts.patient_profiles ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies on patient_profiles first
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

-- Drop the function if it exists (try both public and accounts schemas)
DROP FUNCTION IF EXISTS public.insert_patient_profile_placeholder(text, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS accounts.insert_patient_profile_placeholder(text, text, text, text) CASCADE;

-- Create a SECURITY DEFINER function in public schema so PostgREST can call it
-- This bypasses RLS completely for inserts, which is safe because it only allows NULL profile_id
CREATE OR REPLACE FUNCTION public.insert_patient_profile_placeholder(
  p_first_name text,
  p_last_name text,
  p_date_of_birth text,
  p_gender text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
DECLARE
  v_patient_id uuid;
BEGIN
  -- Insert the patient profile with profile_id = NULL
  INSERT INTO accounts.patient_profiles (
    profile_id,
    first_name,
    last_name,
    date_of_birth,
    gender
  ) VALUES (
    NULL,
    p_first_name,
    p_last_name,
    p_date_of_birth,
    p_gender
  ) RETURNING id INTO v_patient_id;
  
  RETURN v_patient_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.insert_patient_profile_placeholder(text, text, text, text) TO authenticated;

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
  -- PT can see patients mapped to them via pt_patient_map (including placeholders)
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profiles.id
      AND p.user_id = auth.uid()
  )
);

-- INSERT: Allow patients to insert their own profile during signup
-- NOTE: PTs should use the insert_patient_profile_placeholder function instead
CREATE POLICY patient_profiles_insert_own_profile
ON accounts.patient_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- UPDATE: Patients can update their own profile OR PTs can update patients mapped to them
-- CRITICAL: Allow updating profile_id from NULL to user's own profile_id (linking placeholders)
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
  -- Allow updating placeholder (profile_id IS NULL) to link to own profile
  (profile_id IS NULL)
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
  -- Can update own profile (new profile_id matches user's profile)
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  -- PT can update patients mapped to them (any profile_id change allowed for PTs)
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

