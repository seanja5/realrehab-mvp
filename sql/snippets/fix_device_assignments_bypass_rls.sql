-- Alternative approach: Temporarily disable RLS inside the function
-- This is the most reliable way to ensure the function can insert
-- 
-- NOTE: In Supabase, we might not have permission to use SET LOCAL row_security = off
-- But we can try, and if it fails, we'll use the policy approach

BEGIN;

-- First, let's try to modify the RPC function to disable RLS temporarily
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
  
  -- Get or create device (RLS bypassed by SECURITY DEFINER)
  SELECT id INTO v_device_id
  FROM telemetry.devices
  WHERE hardware_serial = p_bluetooth_identifier
  LIMIT 1;
  
  IF v_device_id IS NULL THEN
    -- Create new device (RLS bypassed by SECURITY DEFINER)
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
    -- Try to temporarily disable RLS (may not work in Supabase, but worth trying)
    -- If this fails, we'll catch the exception and try without it
    BEGIN
      -- This might not work in Supabase (requires superuser)
      PERFORM set_config('row_security', 'off', true);
    EXCEPTION WHEN OTHERS THEN
      -- If we can't disable RLS, that's okay - we'll rely on the policy
      NULL;
    END;
    
    -- Create new device assignment
    -- The RLS policy should allow this if current_user = 'postgres'
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
    
    -- Re-enable RLS if we disabled it
    BEGIN
      PERFORM set_config('row_security', 'on', true);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
  
  RETURN v_device_assignment_id;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error for debugging
    RAISE EXCEPTION 'Error in get_or_create_device_assignment: % (SQLSTATE: %). Current user: %. Patient profile ID: %', 
      SQLERRM, SQLSTATE, current_user, v_patient_profile_id;
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

