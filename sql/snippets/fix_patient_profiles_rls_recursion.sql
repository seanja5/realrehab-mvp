BEGIN;

-- Fix infinite recursion in patient_profiles RLS policies
-- The issue: patient_profiles_select_owner joins pt_patient_map, which uses is_patient_owned
-- function that queries patient_profiles, creating a circular dependency

ALTER TABLE accounts.patient_profiles ENABLE ROW LEVEL SECURITY;

-- Drop the problematic SELECT policy
DROP POLICY IF EXISTS patient_profiles_select_owner ON accounts.patient_profiles;

-- Create a new SELECT policy that uses SECURITY DEFINER functions to break recursion
-- Instead of directly joining pt_patient_map in the policy, we'll use a helper function
-- that bypasses RLS to check the mapping

-- First, create a helper function to check if a patient is mapped to the current PT
-- This function bypasses RLS (SECURITY DEFINER) to avoid recursion
CREATE OR REPLACE FUNCTION accounts.is_patient_mapped_to_current_pt(patient_profile_id_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
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

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_patient_mapped_to_current_pt(uuid) TO authenticated;

-- Create new SELECT policy using the helper function (breaks recursion)
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
  -- PT can see patients mapped to them (using helper function to break recursion)
  accounts.is_patient_mapped_to_current_pt(id)
);

-- Also update the UPDATE policy to use the helper function
DROP POLICY IF EXISTS patient_profiles_update ON accounts.patient_profiles;

CREATE POLICY patient_profiles_update
ON accounts.patient_profiles
FOR UPDATE
TO authenticated
USING (
  profile_id IS NULL
  OR
  profile_id IN (SELECT id FROM accounts.profiles WHERE user_id = auth.uid())
  OR
  accounts.is_patient_mapped_to_current_pt(id)
)
WITH CHECK (
  profile_id IN (SELECT id FROM accounts.profiles WHERE user_id = auth.uid())
  OR
  accounts.is_patient_mapped_to_current_pt(id)
);

NOTIFY pgrst, 'reload schema';

COMMIT;

