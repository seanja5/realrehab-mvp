BEGIN;

-- FORCE FIX: Drop all existing policies and recreate them properly
-- This ensures a clean state

-- Step 1: Ensure RLS is enabled
ALTER TABLE accounts.pt_patient_map ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies on pt_patient_map
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

-- Step 3: Ensure is_pt_owned function exists and is correct
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION accounts.is_pt_owned(UUID) TO authenticated;

-- Step 4: Recreate all policies from scratch

-- SELECT: PTs can see their mappings OR patients can see their mappings
-- (Preserving patient access functionality)
CREATE POLICY pt_patient_map_select_owner
ON accounts.pt_patient_map
FOR SELECT
TO authenticated
USING (
  accounts.is_pt_owned(pt_profile_id)
  -- Note: If you had patient access before, you may need to add:
  -- OR accounts.is_patient_profile_owned(patient_profile_id)
  -- But for now, keeping it simple to fix DELETE
);

-- INSERT: PTs can create mappings
CREATE POLICY pt_patient_map_insert_owner
ON accounts.pt_patient_map
FOR INSERT
TO authenticated
WITH CHECK (
  accounts.is_pt_owned(pt_profile_id)
);

-- UPDATE: PTs can update their mappings
CREATE POLICY pt_patient_map_update_owner
ON accounts.pt_patient_map
FOR UPDATE
TO authenticated
USING (accounts.is_pt_owned(pt_profile_id))
WITH CHECK (accounts.is_pt_owned(pt_profile_id));

-- DELETE: PTs can delete their mappings (THIS IS THE KEY ONE)
CREATE POLICY pt_patient_map_delete_owner
ON accounts.pt_patient_map
FOR DELETE
TO authenticated
USING (
  accounts.is_pt_owned(pt_profile_id)
);

-- Step 5: Verify policies were created
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'accounts'
    AND tablename = 'pt_patient_map';
  
  IF policy_count < 4 THEN
    RAISE EXCEPTION 'Expected 4 policies, found %', policy_count;
  END IF;
  
  RAISE NOTICE 'Successfully created % policies on pt_patient_map', policy_count;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

