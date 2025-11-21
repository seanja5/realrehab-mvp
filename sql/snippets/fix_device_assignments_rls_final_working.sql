-- Final working fix: Make sure the RLS policy allows postgres AND validates correctly
-- The key insight: When running as postgres, accounts.is_patient() returns false
-- So we MUST rely on the current_user = 'postgres' check

BEGIN;

DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create policy that explicitly allows postgres role
-- Put postgres check FIRST in WITH CHECK clause
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- CRITICAL: postgres check MUST be first and work correctly
    -- This is what allows SECURITY DEFINER functions to insert
    current_user = 'postgres'::name
    -- Also allow patients directly (in case postgres check doesn't work in some contexts)
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
    )
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
  );

NOTIFY pgrst, 'reload schema';

COMMIT;

