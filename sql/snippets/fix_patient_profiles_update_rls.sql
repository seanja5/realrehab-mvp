BEGIN;

-- Fix patient_profiles UPDATE RLS policy to allow updating profile_id from NULL to valid profile_id
-- This is needed when a patient signs up with an access code and links to a placeholder

-- Drop existing UPDATE policy
DROP POLICY IF EXISTS patient_profiles_update ON accounts.patient_profiles;

-- Create improved UPDATE policy that explicitly allows:
-- 1. Updating rows where profile_id IS NULL (placeholders) to set profile_id to user's profile_id
-- 2. Updating rows where profile_id already matches user's profile_id
-- 3. PTs can update rows for their mapped patients
CREATE POLICY patient_profiles_update
ON accounts.patient_profiles
FOR UPDATE
TO authenticated
USING (
  -- Allow updating if profile_id is NULL (placeholder that can be linked)
  profile_id IS NULL
  OR
  -- Allow updating if profile_id matches current user's profile
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  -- Allow PTs to update their mapped patients
  accounts.is_patient_mapped_to_current_pt(id)
)
WITH CHECK (
  -- After update, profile_id must either:
  -- 1. Match current user's profile (patient updating their own placeholder)
  profile_id IN (
    SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
  )
  OR
  -- 2. Be owned by PT (PT updating their patient's info)
  accounts.is_patient_mapped_to_current_pt(id)
);

NOTIFY pgrst, 'reload schema';

COMMIT;

