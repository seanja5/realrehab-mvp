BEGIN;

-- Fix pt_profiles RLS to ensure PTs can see their own profile
-- This is needed for resolveIdsForCurrentUser to work correctly

ALTER TABLE accounts.pt_profiles ENABLE ROW LEVEL SECURITY;

-- Drop all existing SELECT policies on pt_profiles
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_profiles'
      AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON accounts.pt_profiles;', r.policyname);
  END LOOP;
END $$;

-- Create comprehensive SELECT policy that allows:
-- 1. PTs to see their own profile (for resolveIdsForCurrentUser)
-- 2. Patients to see PTs they're mapped to via pt_patient_map
CREATE POLICY pt_profiles_select_owner_or_mapped
ON accounts.pt_profiles
FOR SELECT
TO authenticated
USING (
  -- PT can see their own profile (CRITICAL for resolveIdsForCurrentUser)
  EXISTS (
    SELECT 1
    FROM accounts.profiles p
    WHERE p.id = pt_profiles.profile_id
      AND p.user_id = auth.uid()
  )
  OR
  -- Patient can see PTs they're mapped to
  EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.patient_profiles pat ON ptm.patient_profile_id = pat.id
    INNER JOIN accounts.profiles p ON pat.profile_id = p.id
    WHERE ptm.pt_profile_id = pt_profiles.id
      AND p.user_id = auth.uid()
  )
);

-- Ensure INSERT, UPDATE policies exist for PTs to manage their own profile
-- Drop existing policies first
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'accounts'
      AND tablename = 'pt_profiles'
      AND cmd IN ('INSERT', 'UPDATE')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON accounts.pt_profiles;', r.policyname);
  END LOOP;
END $$;

-- INSERT policy: PTs can create their own profile
CREATE POLICY pt_profiles_insert_owner
ON accounts.pt_profiles
FOR INSERT
TO authenticated
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

-- UPDATE policy: PTs can update their own profile
CREATE POLICY pt_profiles_update_owner
ON accounts.pt_profiles
FOR UPDATE
TO authenticated
USING (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
)
WITH CHECK (
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
);

NOTIFY pgrst, 'reload schema';

COMMIT;

