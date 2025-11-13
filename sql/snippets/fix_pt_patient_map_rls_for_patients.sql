BEGIN;

-- Fix RLS policies for pt_patient_map to allow patients to access their mappings
-- The issue: is_patient_owned() function requires profile_id to be set, but placeholders have profile_id IS NULL
-- Solution: Create a new helper function that works for both placeholders and linked profiles

-- Create helper function to check if a patient_profile_id belongs to current user
-- Only works for linked profiles (profile_id set) - placeholders require UPDATE first
CREATE OR REPLACE FUNCTION accounts.is_patient_profile_owned(patient_profile_id_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pat
    WHERE pat.id = patient_profile_id_uuid
      AND pat.profile_id IN (
        SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
      )
  );
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_patient_profile_owned(uuid) TO authenticated;

-- Drop existing SELECT policy
DROP POLICY IF EXISTS pt_patient_map_select_owner ON accounts.pt_patient_map;

-- Create improved SELECT policy that allows:
-- 1. PTs to see mappings where they own the pt_profile_id
-- 2. Patients to see mappings where patient_profile_id matches their patient_profiles.id
--    (works for both placeholders with profile_id IS NULL and linked profiles)
CREATE POLICY pt_patient_map_select_owner
ON accounts.pt_patient_map
FOR SELECT
TO authenticated
USING (
  -- PT can see mappings for their own PT profile
  accounts.is_pt_owned(pt_profile_id)
  OR
  -- Patient can see mappings where patient_profile_id belongs to them
  -- This uses the helper function which handles both NULL and set profile_id cases
  accounts.is_patient_profile_owned(patient_profile_id)
);

-- Also update other policies for consistency
DROP POLICY IF EXISTS pt_patient_map_insert_owner ON accounts.pt_patient_map;
DROP POLICY IF EXISTS pt_patient_map_update_owner ON accounts.pt_patient_map;
DROP POLICY IF EXISTS pt_patient_map_delete_owner ON accounts.pt_patient_map;

-- INSERT: PTs can create mappings for their patients
CREATE POLICY pt_patient_map_insert_owner
ON accounts.pt_patient_map
FOR INSERT
TO authenticated
WITH CHECK (
  accounts.is_pt_owned(pt_profile_id)
);

-- UPDATE: Only PTs can update mappings
CREATE POLICY pt_patient_map_update_owner
ON accounts.pt_patient_map
FOR UPDATE
TO authenticated
USING (accounts.is_pt_owned(pt_profile_id))
WITH CHECK (accounts.is_pt_owned(pt_profile_id));

-- DELETE: PTs can delete their mappings
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
FOR DELETE
TO authenticated
USING (accounts.is_pt_owned(pt_profile_id));

NOTIFY pgrst, 'reload schema';

COMMIT;

