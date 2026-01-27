-- ============================================================================
-- ROLLBACK MIGRATION: Remove user_id from telemetry.calibrations
-- ============================================================================
-- This migration reverts all changes made by the forward migration.
-- Use this if you need to rollback the user_id addition.
-- ============================================================================

-- Step 1: Drop the index
DROP INDEX IF EXISTS telemetry.idx_calibrations_user_id;

-- Step 2: Drop all new RLS policies
DROP POLICY IF EXISTS "calibrations_select_own" ON telemetry.calibrations;
DROP POLICY IF EXISTS "calibrations_insert_own" ON telemetry.calibrations;
DROP POLICY IF EXISTS "calibrations_update_own" ON telemetry.calibrations;
DROP POLICY IF EXISTS "calibrations_delete_own" ON telemetry.calibrations;

-- Step 3: Restore original RLS policy (from the latest schema migration)
CREATE POLICY "calibrations_access"
ON telemetry.calibrations
AS PERMISSIVE
FOR ALL
TO public
USING (
  (CURRENT_USER = 'postgres'::name) 
  OR accounts.is_admin() 
  OR (
    accounts.is_pt() AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.pt_profile_id = accounts.current_pt_profile_id()
    )
  ) 
  OR (
    accounts.is_patient() AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.patient_profile_id = accounts.current_patient_profile_id()
    )
  )
)
WITH CHECK (
  (CURRENT_USER = 'postgres'::name) 
  OR accounts.is_admin() 
  OR (
    accounts.is_patient() AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.patient_profile_id = accounts.current_patient_profile_id()
    )
  ) 
  OR (
    accounts.is_pt() AND EXISTS (
      SELECT 1
      FROM telemetry.device_assignments da
      WHERE da.id = calibrations.device_assignment_id
        AND da.pt_profile_id = accounts.current_pt_profile_id()
    )
  )
);

-- Step 4: Drop the trigger
DROP TRIGGER IF EXISTS trg_set_calibration_user_id ON telemetry.calibrations;

-- Step 5: Drop the trigger function
DROP FUNCTION IF EXISTS telemetry.set_calibration_user_id();

-- Step 6: Drop the user_id column
ALTER TABLE telemetry.calibrations
DROP COLUMN IF EXISTS user_id;

