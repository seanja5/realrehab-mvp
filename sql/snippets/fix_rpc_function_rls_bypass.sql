-- Fix the RPC function to explicitly bypass RLS when inserting device assignments
-- This ensures the function can create device assignments even if RLS policies are strict
-- 
-- REVERSIBLE: Run the original create_get_or_create_device_assignment_rpc.sql to revert

BEGIN;

-- Drop and recreate the function with explicit RLS bypass
DROP FUNCTION IF EXISTS public.get_or_create_device_assignment(text) CASCADE;

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
  -- Try to get existing assignment first
  SELECT id INTO v_device_assignment_id
  FROM telemetry.device_assignments
  WHERE device_id = v_device_id
    AND patient_profile_id = v_patient_profile_id
    AND is_active = true
  LIMIT 1;
  
  IF v_device_assignment_id IS NULL THEN
    -- Create new device assignment
    -- Since we're SECURITY DEFINER and running as postgres,
    -- the RLS policy should allow this, but we'll be explicit
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
    
    -- If insert failed due to RLS, raise a helpful error
    IF v_device_assignment_id IS NULL THEN
      RAISE EXCEPTION 'Failed to create device assignment. Current user: %, RLS may be blocking insert.', current_user;
    END IF;
  END IF;
  
  RETURN v_device_assignment_id;
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'Insufficient privileges to create device assignment. Current user: %, Function owner: %', current_user, (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'get_or_create_device_assignment');
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating device assignment: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
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

-- Add comment
COMMENT ON FUNCTION public.get_or_create_device_assignment(text) IS 
  'Gets or creates a device assignment for the current patient. Creates device if it does not exist. Used for calibration data storage. Runs as postgres to bypass RLS.';

-- Verify
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'get_or_create_device_assignment'
  ) THEN
    RAISE EXCEPTION 'Function was not created';
  END IF;
  
  RAISE NOTICE 'Function get_or_create_device_assignment recreated successfully';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

