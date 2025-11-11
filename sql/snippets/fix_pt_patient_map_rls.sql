BEGIN;

ALTER TABLE accounts.pt_patient_map ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies on pt_patient_map
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

-- Create a SECURITY DEFINER function to check PT ownership
-- Note: Function should be owned by postgres/service_role to bypass RLS
-- This avoids RLS recursion when checking policies on pt_patient_map
-- The function queries pt_profiles and profiles without triggering RLS on pt_patient_map
CREATE OR REPLACE FUNCTION accounts.is_pt_owned(pt_profile_id_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = accounts, public
AS $$
  -- Direct join to profiles to check ownership
  -- This bypasses RLS because function runs with DEFINER privileges
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles pp
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE pp.id = pt_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(UUID) TO authenticated;

-- Recreate minimal, non-recursive owner policies
-- Use the SECURITY DEFINER function to avoid RLS recursion

-- SELECT: PT can see mappings where pt_profile_id belongs to them
CREATE POLICY pt_patient_map_select_owner
ON accounts.pt_patient_map
FOR SELECT
TO authenticated
USING (accounts.is_pt_owned(pt_profile_id));

-- INSERT: PT can create mappings where pt_profile_id belongs to them
CREATE POLICY pt_patient_map_insert_owner
ON accounts.pt_patient_map
FOR INSERT
TO authenticated
WITH CHECK (accounts.is_pt_owned(pt_profile_id));

-- UPDATE: PT can update mappings where pt_profile_id belongs to them
CREATE POLICY pt_patient_map_update_owner
ON accounts.pt_patient_map
FOR UPDATE
TO authenticated
USING (accounts.is_pt_owned(pt_profile_id))
WITH CHECK (accounts.is_pt_owned(pt_profile_id));

-- DELETE: PT can delete mappings where pt_profile_id belongs to them
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
FOR DELETE
TO authenticated
USING (accounts.is_pt_owned(pt_profile_id));

NOTIFY pgrst, 'reload schema';

COMMIT;

