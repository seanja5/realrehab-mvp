-- Simplified approach: Make the patient insert check as simple as possible
-- Remove the complex pt_profile_id check for now to see if that's the issue

BEGIN;

-- Drop existing policy
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create a very simple policy that allows patients to insert their own assignments
-- We'll make it permissive first to get it working, then we can tighten it
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
    -- SIMPLIFIED: Allow patients to insert if patient_profile_id matches
    -- Remove the pt_profile_id check for now to see if that's blocking it
    (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
    )
    -- Also allow postgres (put it second in case the patient check doesn't work)
    OR current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
  );

NOTIFY pgrst, 'reload schema';

COMMIT;

