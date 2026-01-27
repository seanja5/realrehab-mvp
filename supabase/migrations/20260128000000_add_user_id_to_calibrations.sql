-- ============================================================================
-- FORWARD MIGRATION: Add user_id to telemetry.calibrations
-- ============================================================================
-- This migration adds a user_id column to telemetry.calibrations to ensure
-- each calibration row is tied to the logged-in user, fixing insert failures
-- for new patient accounts.
--
-- Steps:
-- 1. Add nullable user_id column
-- 2. Backfill user_id from device_assignment -> patient_profile -> profile -> user_id
-- 3. Create trigger to auto-set user_id = auth.uid() on INSERT
-- 4. Update RLS policies to use user_id
-- 5. Add index on user_id for performance
-- ============================================================================

-- Step 1: Add nullable user_id column
ALTER TABLE telemetry.calibrations
ADD COLUMN user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 2: Backfill user_id for existing rows
-- Use the relationship chain: device_assignment -> patient_profile -> profile -> user_id
UPDATE telemetry.calibrations c
SET user_id = p.user_id
FROM telemetry.device_assignments da
JOIN accounts.patient_profiles pp ON da.patient_profile_id = pp.id
JOIN accounts.profiles p ON pp.profile_id = p.id
WHERE c.device_assignment_id = da.id
  AND c.user_id IS NULL;

-- Step 3: Create function to auto-set user_id on INSERT
CREATE OR REPLACE FUNCTION telemetry.set_calibration_user_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO telemetry, accounts, public
AS $$
BEGIN
  -- If user_id is not already set, set it to the current authenticated user
  IF NEW.user_id IS NULL THEN
    NEW.user_id := auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

-- Step 4: Create trigger to call the function before INSERT
CREATE TRIGGER trg_set_calibration_user_id
BEFORE INSERT ON telemetry.calibrations
FOR EACH ROW
EXECUTE FUNCTION telemetry.set_calibration_user_id();

-- Step 5: Drop existing RLS policy and create new ones
DROP POLICY IF EXISTS "calibrations_access" ON telemetry.calibrations;

-- New SELECT policy: users can only see their own calibrations
CREATE POLICY "calibrations_select_own"
ON telemetry.calibrations
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR accounts.is_admin()
  OR (
    accounts.is_pt() AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.pt_profile_id = accounts.current_pt_profile_id()
    )
  )
);

-- New INSERT policy: users can only insert calibrations
-- The trigger will auto-set user_id = auth.uid() if NULL
-- We verify the device_assignment belongs to the user
CREATE POLICY "calibrations_insert_own"
ON telemetry.calibrations
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
  accounts.is_admin()
  OR (
    accounts.is_patient()
    AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.patient_profile_id = accounts.current_patient_profile_id()
    )
    AND (user_id = auth.uid() OR user_id IS NULL)
  )
  OR (
    accounts.is_pt()
    AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.pt_profile_id = accounts.current_pt_profile_id()
    )
    AND (user_id = auth.uid() OR user_id IS NULL)
  )
);

-- New UPDATE policy: users can only update their own calibrations
CREATE POLICY "calibrations_update_own"
ON telemetry.calibrations
AS PERMISSIVE
FOR UPDATE
TO authenticated
USING (
  user_id = auth.uid()
  OR accounts.is_admin()
)
WITH CHECK (
  user_id = auth.uid()
  OR accounts.is_admin()
);

-- New DELETE policy: users can only delete their own calibrations
CREATE POLICY "calibrations_delete_own"
ON telemetry.calibrations
AS PERMISSIVE
FOR DELETE
TO authenticated
USING (
  user_id = auth.uid()
  OR accounts.is_admin()
);

-- Step 6: Add index on user_id for performance
CREATE INDEX IF NOT EXISTS idx_calibrations_user_id
ON telemetry.calibrations(user_id);

-- Step 7: Add comment to document the column
COMMENT ON COLUMN telemetry.calibrations.user_id IS 
  'User ID of the authenticated user who owns this calibration. Auto-set on INSERT via trigger.';

