BEGIN;

-- Fix RLS for rehab_plans SELECT policy
-- The issue: PTs can't see plans for patients they're mapped to if:
-- 1. The plan was created by a different PT (different pt_profile_id), OR
-- 2. The is_patient_owned function isn't working correctly in the policy context
--
-- Solution: Make the SELECT policy explicitly check if the logged-in PT is mapped
-- to the patient, regardless of who created the plan

-- Drop the existing SELECT policy
DROP POLICY IF EXISTS rehab_plans_select_visible ON accounts.rehab_plans;

-- Create a more explicit SELECT policy that checks:
-- 1. PT owns the pt_profile_id in the plan (they created it), OR
-- 2. Patient owns their own profile (they can see their own plans), OR  
-- 3. Logged-in PT is mapped to this patient via pt_patient_map (regardless of plan creator)
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
    -- Case 3: Logged-in PT is mapped to this patient (even if they didn't create the plan)
    -- This is the key fix - check if current PT is mapped to the patient in the plan
    EXISTS (
      SELECT 1
      FROM accounts.pt_patient_map m
      JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
      JOIN accounts.profiles p ON p.id = pt.profile_id
      WHERE m.patient_profile_id = accounts.rehab_plans.patient_profile_id
        AND p.user_id = auth.uid()
    )
  );

-- Reload PostgREST cache
NOTIFY pgrst, 'reload schema';

COMMIT;

