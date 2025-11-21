-- Try to disable RLS inside the SECURITY DEFINER function
-- This uses SET LOCAL row_security = off which should bypass RLS for that operation
-- Note: This might not work in Supabase if we don't have superuser privileges

BEGIN;

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
BEGIN
  -- Get current user ID
  v_current_user_id := auth.uid();
  
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'No authenticated user found. This function must be called via PostgREST with an authenticated session.';
  END IF;
  
  -- Get patient profile ID
  SELECT pp.id INTO v_patient_profile_id
  FROM accounts.patient_profiles pp
  INNER JOIN accounts.profiles p ON pp.profile_id = p.id
  WHERE p.user_id = v_current_user_id
  LIMIT 1;
  
  IF v_patient_profile_id IS NULL THEN
    RAISE EXCEPTION 'No patient profile found for current user (user_id: %)', v_current_user_id;
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
    -- Try to disable RLS for this operation
    -- SET LOCAL only affects the current transaction
    BEGIN
      PERFORM set_config('row_security', 'off', true);
    EXCEPTION WHEN OTHERS THEN
      -- If we can't disable RLS (no superuser), that's okay - we'll rely on the policy
      RAISE NOTICE 'Could not disable RLS (may require superuser): %', SQLERRM;
    END;
    
    -- Insert device assignment
    -- If RLS was disabled, this should work
    -- If not, the RLS policy should allow it
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
    
    -- Re-enable RLS
    BEGIN
      PERFORM set_config('row_security', 'on', true);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
  
  RETURN v_device_assignment_id;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error in get_or_create_device_assignment: % (SQLSTATE: %). User ID: %, Patient Profile ID: %, Current User: %', 
      SQLERRM, SQLSTATE, v_current_user_id, v_patient_profile_id, current_user;
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

GRANT EXECUTE ON FUNCTION public.get_or_create_device_assignment(text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

