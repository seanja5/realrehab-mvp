BEGIN;

-- Ensure the is_pt_owned function exists and is correct
-- This function checks if a pt_profile_id belongs to the current authenticated user
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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(UUID) TO authenticated;

-- Drop existing DELETE policy if it exists
DROP POLICY IF EXISTS pt_patient_map_delete_owner ON accounts.pt_patient_map;

-- Create DELETE policy that allows PTs to delete mappings where they own the pt_profile_id
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
FOR DELETE
TO authenticated
USING (
  -- PT can delete mappings where they own the pt_profile_id
  accounts.is_pt_owned(pt_profile_id)
);

-- Verify the policy was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_patient_map'
      AND policyname = 'pt_patient_map_delete_owner'
  ) THEN
    RAISE EXCEPTION 'Policy pt_patient_map_delete_owner was not created';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

