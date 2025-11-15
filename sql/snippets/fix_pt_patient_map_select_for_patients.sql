BEGIN;

-- FIX: Ensure patients can SELECT their pt_patient_map rows
-- This restores patient access that may have been lost during DELETE policy fixes

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

GRANT EXECUTE ON FUNCTION accounts.is_patient_profile_owned(uuid) TO authenticated;

-- Drop and recreate SELECT policy to ensure patients can see their mappings
DROP POLICY IF EXISTS pt_patient_map_select_owner ON accounts.pt_patient_map;

-- SELECT: PTs can see their mappings OR patients can see their mappings
CREATE POLICY pt_patient_map_select_owner
ON accounts.pt_patient_map
FOR SELECT
TO authenticated
USING (
  -- PT can see mappings for their own PT profile
  accounts.is_pt_owned(pt_profile_id)
  OR
  -- Patient can see mappings where patient_profile_id belongs to them
  accounts.is_patient_profile_owned(patient_profile_id)
);

-- Verify the policy was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_patient_map'
      AND policyname = 'pt_patient_map_select_owner'
      AND cmd = 'SELECT'
  ) THEN
    RAISE EXCEPTION 'SELECT policy was not created';
  END IF;
  
  RAISE NOTICE 'SELECT policy created successfully - patients can now see their mappings';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

