BEGIN;

-- RESTORE SCRIPT: Restores pt_patient_map policies to allow both PTs and patients
-- Run this if the force fix breaks patient functionality

-- Ensure is_pt_owned function exists
CREATE OR REPLACE FUNCTION accounts.is_pt_owned(pt_profile_id_uuid UUID)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = pt_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;

-- Ensure is_patient_profile_owned function exists (for patient access)
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

GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION accounts.is_patient_profile_owned(uuid) TO authenticated;

-- Drop all existing policies
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_patient_map'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON accounts.pt_patient_map;', r.policyname);
  END LOOP;
END $$;

-- SELECT: PTs can see their mappings OR patients can see their mappings
CREATE POLICY pt_patient_map_select_owner
ON accounts.pt_patient_map
FOR SELECT
TO authenticated
USING (
  accounts.is_pt_owned(pt_profile_id)
  OR
  accounts.is_patient_profile_owned(patient_profile_id)
);

-- INSERT: PTs can create mappings
CREATE POLICY pt_patient_map_insert_owner
ON accounts.pt_patient_map
FOR INSERT
TO authenticated
WITH CHECK (
  accounts.is_pt_owned(pt_profile_id)
);

-- UPDATE: PTs can update their mappings
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
USING (
  accounts.is_pt_owned(pt_profile_id)
);

NOTIFY pgrst, 'reload schema';

COMMIT;

