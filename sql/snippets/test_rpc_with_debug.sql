-- Test the RPC function with detailed debugging
-- This will help us see exactly what's happening

CREATE OR REPLACE FUNCTION public.test_device_assignment_insert(
  p_bluetooth_identifier text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = telemetry, accounts, public
AS $$
DECLARE
  v_device_id uuid;
  v_patient_profile_id uuid;
  v_current_user_id uuid;
  v_current_user_text text;
  v_is_patient boolean;
  v_current_patient_id uuid;
  v_debug_info jsonb;
BEGIN
  -- Collect debug info
  v_current_user_text := current_user::text;
  v_current_user_id := auth.uid();
  
  -- Get patient profile ID
  SELECT pp.id INTO v_patient_profile_id
  FROM accounts.patient_profiles pp
  INNER JOIN accounts.profiles p ON pp.profile_id = p.id
  WHERE p.user_id = v_current_user_id
  LIMIT 1;
  
  -- Get device ID (or create one)
  SELECT id INTO v_device_id
  FROM telemetry.devices
  WHERE hardware_serial = p_bluetooth_identifier
  LIMIT 1;
  
  IF v_device_id IS NULL THEN
    INSERT INTO telemetry.devices (hardware_serial, status)
    VALUES (p_bluetooth_identifier, 'unpaired'::telemetry.device_status)
    RETURNING id INTO v_device_id;
  END IF;
  
  -- Check if we're a patient
  SELECT accounts.is_patient() INTO v_is_patient;
  SELECT accounts.current_patient_profile_id() INTO v_current_patient_id;
  
  -- Try to insert device assignment and catch any errors
  BEGIN
    INSERT INTO telemetry.device_assignments (
      device_id,
      patient_profile_id,
      pt_profile_id,
      is_active
    ) VALUES (
      v_device_id,
      v_patient_profile_id,
      NULL,
      true
    );
    
    v_debug_info := jsonb_build_object(
      'success', true,
      'current_user', v_current_user_text,
      'auth_uid', v_current_user_id,
      'is_patient', v_is_patient,
      'current_patient_id', v_current_patient_id,
      'patient_profile_id', v_patient_profile_id,
      'device_id', v_device_id,
      'message', 'Insert succeeded'
    );
    
  EXCEPTION WHEN OTHERS THEN
    v_debug_info := jsonb_build_object(
      'success', false,
      'current_user', v_current_user_text,
      'auth_uid', v_current_user_id,
      'is_patient', v_is_patient,
      'current_patient_id', v_current_patient_id,
      'patient_profile_id', v_patient_profile_id,
      'device_id', v_device_id,
      'error', SQLERRM,
      'sqlstate', SQLSTATE
    );
  END;
  
  RETURN v_debug_info;
END;
$$;

GRANT EXECUTE ON FUNCTION public.test_device_assignment_insert(text) TO authenticated;

