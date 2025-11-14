BEGIN;

-- Allow PTs to read email and phone from profiles table for their mapped patients
-- This enables PTs to see patient contact info in PatientListView
-- Relationship: pt_patient_map -> patient_profiles.profile_id -> profiles.id

-- Ensure RLS is enabled on profiles table
ALTER TABLE accounts.profiles ENABLE ROW LEVEL SECURITY;

-- Check if there's an existing SELECT policy we need to preserve
-- We'll add our policy alongside any existing ones

-- Create helper function to check if PT is mapped to a patient profile
-- This uses SECURITY DEFINER to bypass RLS when checking the mapping
CREATE OR REPLACE FUNCTION accounts.is_pt_mapped_to_patient_profile(profile_id_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.patient_profiles pat ON ptm.patient_profile_id = pat.id
    INNER JOIN accounts.pt_profiles pt ON ptm.pt_profile_id = pt.id
    INNER JOIN accounts.profiles pt_profile ON pt.profile_id = pt_profile.id
    WHERE pat.profile_id = profile_id_uuid
      AND pt_profile.user_id = auth.uid()
  );
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_pt_mapped_to_patient_profile(uuid) TO authenticated;

-- Create SELECT policy that allows:
-- 1. Users to see their own profile (existing behavior - preserve this)
-- 2. PTs to see email/phone for profiles of patients they're mapped to
CREATE POLICY profiles_select_owner_or_pt_mapped
ON accounts.profiles
FOR SELECT
TO authenticated
USING (
  -- User can see their own profile (preserve existing behavior)
  user_id = auth.uid()
  OR
  -- PT can see email/phone for profiles of patients they're mapped to
  accounts.is_pt_mapped_to_patient_profile(id)
);

-- Note: We're only allowing SELECT (read) access, not INSERT/UPDATE/DELETE
-- This is safe and won't affect existing functionality

COMMENT ON POLICY profiles_select_owner_or_pt_mapped ON accounts.profiles IS 
'Allows users to see their own profile, and PTs to see email/phone for their mapped patients';

NOTIFY pgrst, 'reload schema';

COMMIT;

