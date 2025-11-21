-- Re-enable RLS with a working policy
-- Run this AFTER confirming the insert works with RLS disabled

BEGIN;

-- Re-enable RLS
ALTER TABLE telemetry.device_assignments ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;
DROP POLICY IF EXISTS device_assignments_postgres_all ON telemetry.device_assignments;

-- Create a simple working policy
-- Since we know the function runs as postgres, let's make sure that works
CREATE POLICY device_assignments_postgres_all
  ON telemetry.device_assignments
  FOR ALL
  TO postgres
  USING (true)
  WITH CHECK (true);

-- Also allow patients to insert their own
CREATE POLICY device_assignments_patients
  ON telemetry.device_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    accounts.is_patient() 
    AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
  );

-- Allow reads/updates for admins, PTs, and patients
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  TO authenticated
  USING (
    accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  );

NOTIFY pgrst, 'reload schema';

COMMIT;

