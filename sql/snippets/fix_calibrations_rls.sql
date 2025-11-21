-- Fix RLS policy for calibrations table to allow patients to insert their calibration data
-- The device_assignments insert is now working, but calibrations is blocked

BEGIN;

-- Check current RLS status
DO $$
DECLARE
  v_rls_enabled boolean;
  v_policy_count int;
BEGIN
  SELECT rowsecurity INTO v_rls_enabled
  FROM pg_tables
  WHERE schemaname = 'telemetry'
    AND tablename = 'calibrations';
  
  RAISE NOTICE 'RLS enabled on calibrations: %', v_rls_enabled;
  
  SELECT COUNT(*) INTO v_policy_count
  FROM pg_policy
  WHERE polrelid = 'telemetry.calibrations'::regclass;
  
  RAISE NOTICE 'Number of policies on calibrations: %', v_policy_count;
END $$;

-- Drop existing policies
DROP POLICY IF EXISTS calibrations_access ON telemetry.calibrations;

-- Create a policy that allows:
-- 1. Postgres role (for SECURITY DEFINER functions)
-- 2. Patients to insert their own calibrations (via device_assignment_id)
-- 3. PTs and admins to read/update
CREATE POLICY calibrations_access
  ON telemetry.calibrations
  FOR ALL
  USING (
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (
      accounts.is_pt() 
      AND EXISTS (
        SELECT 1
        FROM telemetry.device_assignments da
        WHERE da.id = telemetry.calibrations.device_assignment_id
          AND da.pt_profile_id = accounts.current_pt_profile_id()
      )
    )
    OR (
      accounts.is_patient()
      AND EXISTS (
        SELECT 1
        FROM telemetry.device_assignments da
        WHERE da.id = telemetry.calibrations.device_assignment_id
          AND da.patient_profile_id = accounts.current_patient_profile_id()
      )
    )
  )
  WITH CHECK (
    -- Allow postgres (SECURITY DEFINER functions)
    current_user = 'postgres'::name
    OR accounts.is_admin()
    -- Allow patients to insert their own calibrations
    OR (
      accounts.is_patient()
      AND EXISTS (
        SELECT 1
        FROM telemetry.device_assignments da
        WHERE da.id = telemetry.calibrations.device_assignment_id
          AND da.patient_profile_id = accounts.current_patient_profile_id()
      )
    )
    -- Allow PTs to insert for their patients
    OR (
      accounts.is_pt()
      AND EXISTS (
        SELECT 1
        FROM telemetry.device_assignments da
        WHERE da.id = telemetry.calibrations.device_assignment_id
          AND da.pt_profile_id = accounts.current_pt_profile_id()
      )
    )
  );

-- Also grant explicit permissions
GRANT INSERT, SELECT, UPDATE ON telemetry.calibrations TO authenticated;
GRANT ALL ON telemetry.calibrations TO postgres;

NOTIFY pgrst, 'reload schema';

COMMIT;

