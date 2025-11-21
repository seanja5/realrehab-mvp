-- Final fix for device_assignments RLS - Use a different approach
-- Instead of relying on CURRENT_USER = 'postgres', we'll use a more permissive policy
-- that explicitly allows the RPC function context

BEGIN;

-- Drop existing policy
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

-- Create a more permissive policy that allows:
-- 1. Postgres role (for SECURITY DEFINER functions)
-- 2. Admins
-- 3. PTs for their patients
-- 4. Patients for their own assignments
-- 
-- Key change: We check for postgres role using multiple methods to ensure it works
CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- Method 1: Check current_user (should be postgres in SECURITY DEFINER functions)
    current_user = 'postgres'
    -- Method 2: Check if we're in a SECURITY DEFINER function context
    -- (This is a fallback - if current_user check doesn't work)
    OR (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_or_create_device_assignment') = current_user
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- Same checks for WITH CHECK clause
    current_user = 'postgres'
    OR (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_or_create_device_assignment') = current_user
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
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
  );

-- Actually, the subquery approach above is too complex and might not work.
-- Let's try a simpler approach: Just make the policy more permissive for inserts
-- by allowing patients to insert when pt_profile_id is NULL or matches their PT

-- Drop and recreate with simpler logic
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

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
    -- For inserts, be more permissive - allow postgres OR allow patients to insert their own
    current_user = 'postgres'::name
    OR accounts.is_admin()
    OR (accounts.is_pt() AND (
      accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id
      OR telemetry.device_assignments.pt_profile_id IS NULL
    ))
    OR (
      accounts.is_patient() 
      AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id
      -- Allow insert if pt_profile_id is NULL (patient not linked yet) OR matches their PT
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
  );

NOTIFY pgrst, 'reload schema';

COMMIT;

