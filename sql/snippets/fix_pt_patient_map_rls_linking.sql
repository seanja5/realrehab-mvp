BEGIN;

ALTER TABLE accounts.pt_patient_map ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies on pt_patient_map first (they depend on functions)
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

-- Drop existing functions (to allow parameter name changes)
-- Must drop after policies since policies depend on functions
DROP FUNCTION IF EXISTS accounts.is_pt_owned(UUID) CASCADE;
DROP FUNCTION IF EXISTS accounts.is_patient_owned(UUID) CASCADE;

-- Create a SECURITY DEFINER function to check PT ownership
CREATE FUNCTION accounts.is_pt_owned(pt_profile_id_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles pp
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE pp.id = pt_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;

-- Create a SECURITY DEFINER function to check patient ownership
CREATE FUNCTION accounts.is_patient_owned(patient_profile_id_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pat
    INNER JOIN accounts.profiles p ON pat.profile_id = p.id
    WHERE pat.id = patient_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION accounts.is_patient_owned(UUID) TO authenticated;

-- SELECT: PT can see mappings where pt_profile_id belongs to them
-- OR patient can see mappings where patient_profile_id belongs to them
CREATE POLICY pt_patient_map_select_owner
ON accounts.pt_patient_map
FOR SELECT
TO authenticated
USING (
  accounts.is_pt_owned(pt_profile_id)
  OR
  accounts.is_patient_owned(patient_profile_id)
);

-- INSERT: PT can create mappings where pt_profile_id belongs to them
-- OR patient can create mappings where patient_profile_id belongs to them
CREATE POLICY pt_patient_map_insert_owner
ON accounts.pt_patient_map
FOR INSERT
TO authenticated
WITH CHECK (
  accounts.is_pt_owned(pt_profile_id)
  OR
  accounts.is_patient_owned(patient_profile_id)
);

-- UPDATE: PT can update mappings where pt_profile_id belongs to them
-- OR patient can update mappings where patient_profile_id belongs to them
CREATE POLICY pt_patient_map_update_owner
ON accounts.pt_patient_map
FOR UPDATE
TO authenticated
USING (
  accounts.is_pt_owned(pt_profile_id)
  OR
  accounts.is_patient_owned(patient_profile_id)
)
WITH CHECK (
  accounts.is_pt_owned(pt_profile_id)
  OR
  accounts.is_patient_owned(patient_profile_id)
);

-- DELETE: PT can delete mappings where pt_profile_id belongs to them
-- OR patient can delete mappings where patient_profile_id belongs to them
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
FOR DELETE
TO authenticated
USING (
  accounts.is_pt_owned(pt_profile_id)
  OR
  accounts.is_patient_owned(patient_profile_id)
);

NOTIFY pgrst, 'reload schema';

COMMIT;

