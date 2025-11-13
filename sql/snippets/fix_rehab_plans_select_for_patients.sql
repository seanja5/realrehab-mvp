BEGIN;

-- Fix rehab_plans SELECT policy to allow patients to see their own rehab plans
-- Current policy only allows PTs to see plans, but patients also need to see their assigned plans

-- Drop existing SELECT policy
DROP POLICY IF EXISTS rehab_plans_select_owner ON accounts.rehab_plans;

-- Create new SELECT policy that allows:
-- 1. PTs to see plans they created for their patients (existing behavior)
-- 2. Patients to see plans assigned to them (NEW - needed for PTDetailView)
CREATE POLICY rehab_plans_select_owner
ON accounts.rehab_plans
FOR SELECT
TO authenticated
USING (
  -- Allow PTs to see plans they created
  (
    EXISTS (
      SELECT 1
      FROM accounts.pt_profiles pt
      JOIN accounts.profiles p ON p.id = pt.profile_id
      WHERE p.user_id = auth.uid()
        AND pt.id = rehab_plans.pt_profile_id
    )
    AND EXISTS (
      SELECT 1
      FROM accounts.pt_patient_map m
      WHERE m.pt_profile_id = rehab_plans.pt_profile_id
        AND m.patient_profile_id = rehab_plans.patient_profile_id
    )
  )
  OR
  -- Allow patients to see plans assigned to them (NEW)
  (
    EXISTS (
      SELECT 1
      FROM accounts.patient_profiles pat
      JOIN accounts.profiles p ON p.id = pat.profile_id
      WHERE p.user_id = auth.uid()
        AND pat.id = rehab_plans.patient_profile_id
    )
    AND EXISTS (
      SELECT 1
      FROM accounts.pt_patient_map m
      WHERE m.pt_profile_id = rehab_plans.pt_profile_id
        AND m.patient_profile_id = rehab_plans.patient_profile_id
    )
  )
);

NOTIFY pgrst, 'reload schema';
COMMIT;

