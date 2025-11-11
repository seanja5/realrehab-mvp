BEGIN;

-- Complete fix for rehab_plans RLS
-- Drop ALL policies first, then recreate functions, then recreate policies
-- This avoids dependency errors

-- 1) Drop ALL existing policies on accounts.rehab_plans
DROP POLICY IF EXISTS rehab_plans_select_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_insert_pt_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_update_pt_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_delete_pt_owner ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_insert_by_pt ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_select_visible ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_update_by_pt ON accounts.rehab_plans;
DROP POLICY IF EXISTS rehab_plans_delete_by_pt ON accounts.rehab_plans;

-- 2) Now we can safely drop and recreate the helper functions
DROP FUNCTION IF EXISTS accounts.is_pt_owned(uuid);
DROP FUNCTION IF EXISTS accounts.is_patient_owned(uuid);

-- Recreate is_pt_owned: PT owns row if pt_profiles.profile_id -> profiles.user_id = auth.uid()
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

-- Recreate is_patient_owned: row is "owned" if (a) it's the logged-in patient, or (b) logged-in PT is mapped via pt_patient_map
CREATE FUNCTION accounts.is_patient_owned(p_patient_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = accounts, public
AS $$
  -- Check if patient owns their own profile
  SELECT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pp
    JOIN accounts.profiles p ON p.id = pp.profile_id
    WHERE pp.id = p_patient_profile_id
      AND p.user_id = auth.uid()
  )
  -- OR check if logged-in PT is mapped to this patient
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

-- 3) Enable RLS
ALTER TABLE accounts.rehab_plans ENABLE ROW LEVEL SECURITY;

-- 4) Recreate all policies with correct logic

-- INSERT: PT can create plan if they are mapped to the patient (assumption: PT is the ONLY PT)
-- Simplified: just check that PT is mapped to patient, not that they own the pt_profile_id
CREATE POLICY rehab_plans_insert_by_pt
  ON accounts.rehab_plans
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- PT must be mapped to this patient via pt_patient_map
    EXISTS (
      SELECT 1
      FROM accounts.pt_patient_map m
      JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
      JOIN accounts.profiles p ON p.id = pt.profile_id
      WHERE m.patient_profile_id = accounts.rehab_plans.patient_profile_id
        AND m.pt_profile_id = accounts.rehab_plans.pt_profile_id
        AND p.user_id = auth.uid()
    )
  );

-- SELECT: PT owns pt_profile_id OR patient is owned OR PT is mapped to patient
CREATE POLICY rehab_plans_select_visible
  ON accounts.rehab_plans
  FOR SELECT
  TO authenticated
  USING (
    -- Case 1: PT owns the pt_profile_id in the plan (they created it)
    accounts.is_pt_owned(pt_profile_id)
    OR
    -- Case 2: Patient owns their own profile (they can see their own plans)
    EXISTS (
      SELECT 1
      FROM accounts.patient_profiles pp
      JOIN accounts.profiles p ON p.id = pp.profile_id
      WHERE pp.id = accounts.rehab_plans.patient_profile_id
        AND p.user_id = auth.uid()
    )
    OR
    -- Case 3: Logged-in PT is mapped to this patient (regardless of who created the plan)
    EXISTS (
      SELECT 1
      FROM accounts.pt_patient_map m
      JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
      JOIN accounts.profiles p ON p.id = pt.profile_id
      WHERE m.patient_profile_id = accounts.rehab_plans.patient_profile_id
        AND p.user_id = auth.uid()
    )
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

-- 5) Reload PostgREST cache
NOTIFY pgrst, 'reload schema';

COMMIT;
