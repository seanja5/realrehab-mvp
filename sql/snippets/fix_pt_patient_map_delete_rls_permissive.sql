BEGIN;

-- PERMISSIVE FIX: Make the DELETE policy explicitly permissive
-- Sometimes policies need to be explicitly marked as permissive

-- Drop existing DELETE policy
DROP POLICY IF EXISTS pt_patient_map_delete_owner ON accounts.pt_patient_map;

-- Create DELETE policy with explicit PERMISSIVE (default but being explicit)
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
AS PERMISSIVE  -- Explicitly permissive
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = pt_patient_map.pt_profile_id
      AND p.user_id = auth.uid()
  )
);

-- Also ensure the table has RLS enabled
ALTER TABLE accounts.pt_patient_map ENABLE ROW LEVEL SECURITY;

-- Verify
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
  
  RAISE NOTICE 'DELETE policy created with PERMISSIVE flag';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

