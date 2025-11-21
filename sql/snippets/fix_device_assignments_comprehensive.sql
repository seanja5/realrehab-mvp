-- Comprehensive fix for device_assignments RLS issue
-- This uses multiple strategies to ensure the RPC function can insert

BEGIN;

-- Strategy 1: Create a helper function to check if we're in a SECURITY DEFINER context
CREATE OR REPLACE FUNCTION telemetry.is_security_definer_context()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  -- Check if current_user is postgres (which SECURITY DEFINER functions run as)
  SELECT current_user::text = 'postgres';
$$;

-- Strategy 2: Update the RLS policy to use the helper function AND explicit checks
DROP POLICY IF EXISTS device_assignments_access ON telemetry.device_assignments;

CREATE POLICY device_assignments_access
  ON telemetry.device_assignments
  FOR ALL
  USING (
    -- Multiple ways to check for postgres/SECURITY DEFINER context
    current_user::text = 'postgres'
    OR telemetry.is_security_definer_context()
    OR accounts.is_admin()
    OR (accounts.is_pt() AND accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    OR (accounts.is_patient() AND accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  WITH CHECK (
    -- CRITICAL: For inserts, we need to be even more permissive
    -- Check postgres in multiple ways
    current_user::text = 'postgres'
    OR telemetry.is_security_definer_context()
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

-- Strategy 3: Also ensure the RPC function has better error handling
CREATE OR REPLACE FUNCTION public.get_or_create_device_assignment(
  p_bluetooth_identifier text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = telemetry, accounts, public
AS $$
DECLARE
  v_device_id uuid;
  v_device_assignment_id uuid;
  v_patient_profile_id uuid;
  v_pt_profile_id uuid;
  v_current_user_id uuid;
  v_current_user_text text;
BEGIN
  -- Log current user for debugging
  v_current_user_text := current_user::text;
  
  -- Get current user ID (before switching role)
  v_current_user_id := auth.uid();
  
  -- Get patient profile ID for current user
  SELECT pp.id INTO v_patient_profile_id
  FROM accounts.patient_profiles pp
  INNER JOIN accounts.profiles p ON pp.profile_id = p.id
  WHERE p.user_id = v_current_user_id
  LIMIT 1;
  
  IF v_patient_profile_id IS NULL THEN
    RAISE EXCEPTION 'No patient profile found for current user';
  END IF;
  
  -- Get or create device
  SELECT id INTO v_device_id
  FROM telemetry.devices
  WHERE hardware_serial = p_bluetooth_identifier
  LIMIT 1;
  
  IF v_device_id IS NULL THEN
    INSERT INTO telemetry.devices (
      hardware_serial,
      status
    ) VALUES (
      p_bluetooth_identifier,
      'unpaired'::telemetry.device_status
    ) RETURNING id INTO v_device_id;
  END IF;
  
  -- Get PT profile ID if patient is linked to a PT
  SELECT ptm.pt_profile_id INTO v_pt_profile_id
  FROM accounts.pt_patient_map ptm
  WHERE ptm.patient_profile_id = v_patient_profile_id
  LIMIT 1;
  
  -- Get or create device assignment
  SELECT id INTO v_device_assignment_id
  FROM telemetry.device_assignments
  WHERE device_id = v_device_id
    AND patient_profile_id = v_patient_profile_id
    AND is_active = true
  LIMIT 1;
  
  IF v_device_assignment_id IS NULL THEN
    -- Try to insert - this is where RLS might block us
    BEGIN
      INSERT INTO telemetry.device_assignments (
        device_id,
        patient_profile_id,
        pt_profile_id,
        is_active
      ) VALUES (
        v_device_id,
        v_patient_profile_id,
        v_pt_profile_id,
        true
      ) RETURNING id INTO v_device_assignment_id;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE EXCEPTION 'RLS blocked insert. Current user: %, Is postgres: %, Patient profile: %', 
          v_current_user_text, 
          (v_current_user_text = 'postgres'),
          v_patient_profile_id;
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Error inserting device assignment: % (SQLSTATE: %). Current user: %', 
          SQLERRM, SQLSTATE, v_current_user_text;
    END;
  END IF;
  
  RETURN v_device_assignment_id;
END;
$$;

-- Ensure function is owned by postgres
DO $$
BEGIN
  BEGIN
    ALTER FUNCTION public.get_or_create_device_assignment(text) OWNER TO postgres;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not change function owner: %', SQLERRM;
  END;
END $$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_or_create_device_assignment(text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

