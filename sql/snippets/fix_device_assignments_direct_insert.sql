-- Different approach: Instead of relying on SECURITY DEFINER to bypass RLS,
-- let's make the RLS policy allow patients to directly insert their own device assignments
-- This way, the RPC function can insert on behalf of the patient

BEGIN;

-- Drop all existing policies
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;
DROP POLICY IF EXISTS device_assignments_insert_postgres ON telemetry.device_assignments;

-- Create a policy that allows:
-- 1. Postgres role (for SECURITY DEFINER functions) - try both current_user and explicit role check
-- 2. Patients to insert their own device assignments (this is the key!)
-- 3. PTs and admins as before

CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- Allow postgres (SECURITY DEFINER functions)
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- CRITICAL: For inserts, allow patients to create their own assignments
    -- This should work even if SECURITY DEFINER context isn't recognized
    (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
      -- Allow pt_profile_id to be NULL (patient not linked yet) or match their PT
      AND (
        telemetry.device_assignments.pt_profile_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM accounts.pt_patient_map ptm
          WHERE ptm.patient_profile_id = accounts.current_patient_profile_id()
            AND ptm.pt_profile_id = telemetry.device_assignments.pt_profile_id
        )
      )
    )
    -- Also allow postgres (SECURITY DEFINER)
    OR current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
  );

-- Verify
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policy
    WHERE polrelid = 'telemetry.device_assignments'::regclass
      AND polname = 'device_assignments_access'
  ) THEN
    RAISE EXCEPTION 'Policy was not created';
  END IF;
  
  RAISE NOTICE 'Policy created with patient insert permission';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

