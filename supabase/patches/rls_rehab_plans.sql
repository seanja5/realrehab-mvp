BEGIN;

-- 1) Drop any existing policies on accounts.rehab_plans that reference the helper functions
DROP POLICY IF EXISTS rehab_plans_select_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_insert_pt_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_update_pt_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_delete_pt_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_insert_by_pt ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_select_visible ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_update_by_pt ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_delete_by_pt ON accounts.rehab_plans;

-- 2) Drop and recreate helper functions by signature with stable arg names
DROP FUNCTION IF EXISTS accounts.is_pt_owned(uuid);
DROP FUNCTION IF EXISTS accounts.is_patient_owned(uuid);

-- accounts.is_pt_owned: PT owns row if pt_profiles.profile_id -> profiles.user_id = auth.uid()
CREATE FUNCTION accounts.is_pt_owned(p_pt_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles pt
    JOIN accounts.profiles p ON p.id = pt.profile_id
    WHERE pt.id = p_pt_profile_id
      AND p.user_id = auth.uid()
  );
$$;

-- accounts.is_patient_owned: row is "owned" if (a) it's the logged-in patient, or (b) logged-in PT is mapped via pt_patient_map
CREATE FUNCTION accounts.is_patient_owned(p_patient_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = accounts, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pp
    JOIN accounts.profiles p ON p.id = pp.profile_id
    WHERE pp.id = p_patient_profile_id
      AND p.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map m
    JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
    JOIN accounts.profiles p2 ON p2.id = pt.profile_id
    WHERE m.patient_profile_id = p_patient_profile_id
      AND p2.user_id = auth.uid()
  );
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION accounts.is_patient_owned(uuid) TO authenticated;

-- 3) Enable RLS and create policies on accounts.rehab_plans
ALTER TABLE accounts.rehab_plans ENABLE ROW LEVEL SECURITY;

-- INSERT: PT must own pt_profile_id AND patient must be owned (by patient themselves or mapped to PT)
CREATE POLICY rehab_plans_insert_by_pt
  ON accounts.rehab_plans
  FOR INSERT
  TO authenticated
  WITH CHECK (
    accounts.is_pt_owned(pt_profile_id) AND
    accounts.is_patient_owned(patient_profile_id)
  );

-- SELECT: PT owns pt_profile_id OR patient is owned
CREATE POLICY rehab_plans_select_visible
  ON accounts.rehab_plans
  FOR SELECT
  TO authenticated
  USING (
    accounts.is_pt_owned(pt_profile_id)
    OR accounts.is_patient_owned(patient_profile_id)
  );

-- UPDATE: PT owns pt_profile_id (for both USING and WITH CHECK)
CREATE POLICY rehab_plans_update_by_pt
  ON accounts.rehab_plans
  FOR UPDATE
  TO authenticated
  USING (accounts.is_pt_owned(pt_profile_id))
  WITH CHECK (accounts.is_pt_owned(pt_profile_id));

-- DELETE: PT owns pt_profile_id
CREATE POLICY rehab_plans_delete_by_pt
  ON accounts.rehab_plans
  FOR DELETE
  TO authenticated
  USING (accounts.is_pt_owned(pt_profile_id));

-- 4) Reload PostgREST cache
NOTIFY pgrst, 'reload schema';

COMMIT;

