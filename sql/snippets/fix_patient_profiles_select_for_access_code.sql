BEGIN;

-- Fix patient_profiles SELECT policy to allow querying placeholders by access code
-- This is needed so patients can find their placeholder during signup

-- Drop existing SELECT policy
DROP POLICY IF EXISTS patient_profiles_select_owner ON accounts.patient_profiles;

-- Create new SELECT policy that allows:
-- 1. Querying your own patient profile (profile_id matches your profile)
-- 2. Querying placeholders (profile_id IS NULL) - needed for access code lookup during signup
-- 3. Querying patients mapped to your PT (via is_patient_mapped_to_current_pt)
CREATE POLICY patient_profiles_select_owner
ON accounts.patient_profiles
FOR SELECT
TO authenticated
USING (
  -- Allow querying your own profile
  (profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  ))
  OR
  -- Allow querying placeholders (profile_id IS NULL) - needed for access code lookup
  -- This is safe because placeholders only contain name, DOB, gender, and access_code
  (profile_id IS NULL)
  OR
  -- Allow PTs to query their mapped patients
  accounts.is_patient_mapped_to_current_pt(id)
);

NOTIFY pgrst, 'reload schema';
COMMIT;

