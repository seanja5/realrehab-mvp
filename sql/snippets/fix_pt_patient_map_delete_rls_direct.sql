BEGIN;

-- DIRECT FIX: Create a DELETE policy that directly checks ownership
-- This bypasses potential function issues

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

GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(UUID) TO authenticated;

-- Drop existing DELETE policy
DROP POLICY IF EXISTS pt_patient_map_delete_owner ON accounts.pt_patient_map;

-- Create DELETE policy with direct ownership check (alternative approach)
-- This checks directly in the policy instead of relying solely on the function
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
FOR DELETE
TO authenticated
USING (
  -- Direct check: pt_profile_id must belong to current user
  EXISTS (
    SELECT 1
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = pt_patient_map.pt_profile_id
      AND p.user_id = auth.uid()
  )
);

-- Verify policy was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_patient_map'
      AND policyname = 'pt_patient_map_delete_owner'
      AND cmd = 'DELETE'
  ) THEN
    RAISE EXCEPTION 'DELETE policy was not created';
  END IF;
  
  RAISE NOTICE 'DELETE policy created successfully';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

