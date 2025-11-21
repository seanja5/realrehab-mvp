-- RPC Function: Get or Create Device Assignment
-- This function allows patients to get or create a device assignment for calibration
-- It bypasses RLS to allow patients to create devices and device assignments
-- 
-- REVERSIBLE: To revert, simply run: DROP FUNCTION IF EXISTS public.get_or_create_device_assignment(text);

BEGIN;

-- Drop function if it exists (in both public and telemetry schemas for cleanup)
DROP FUNCTION IF EXISTS public.get_or_create_device_assignment(text) CASCADE;
DROP FUNCTION IF EXISTS telemetry.get_or_create_device_assignment(text) CASCADE;

-- Create SECURITY DEFINER function in public schema so PostgREST can call it via RPC
-- This function creates a device (if needed) and device assignment (if needed)
-- It bypasses RLS, which is safe because:
-- 1. It validates that the patient_profile_id belongs to the current user
-- 2. It only creates device assignments for the current patient
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
  
  -- Get or create device assignment (RLS bypassed)
  SELECT id INTO v_device_assignment_id
  FROM telemetry.device_assignments
  WHERE device_id = v_device_id
    AND patient_profile_id = v_patient_profile_id
    AND is_active = true
  LIMIT 1;
  
  IF v_device_assignment_id IS NULL THEN
    -- Create new device assignment (RLS bypassed by SECURITY DEFINER)
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
  END IF;
  
  RETURN v_device_assignment_id;
END;
$$;

-- Ensure function is owned by postgres (bypasses RLS)
-- Note: In Supabase, the function should already be owned by postgres by default
-- but we explicitly set it to ensure RLS bypass
DO $$
BEGIN
  -- Try to set owner to postgres (may fail if not superuser, but that's okay)
  BEGIN
    ALTER FUNCTION public.get_or_create_device_assignment(text) OWNER TO postgres;
  EXCEPTION WHEN OTHERS THEN
    -- If we can't change owner, that's okay - it should already be postgres
    RAISE NOTICE 'Could not change function owner (may already be postgres): %', SQLERRM;
  END;
END $$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_or_create_device_assignment(text) TO authenticated;

-- Also grant to anon users (if needed for testing, but authenticated should be enough)
-- GRANT EXECUTE ON FUNCTION public.get_or_create_device_assignment(text) TO anon;

-- Add comment
COMMENT ON FUNCTION public.get_or_create_device_assignment(text) IS 
  'Gets or creates a device assignment for the current patient. Creates device if it does not exist. Used for calibration data storage.';

-- Verify the function was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'get_or_create_device_assignment'
  ) THEN
    RAISE EXCEPTION 'Function get_or_create_device_assignment was not created';
  END IF;
  
  RAISE NOTICE 'Function get_or_create_device_assignment created successfully in public schema';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- REVERSAL SCRIPT (run this to revert):
-- DROP FUNCTION IF EXISTS public.get_or_create_device_assignment(text);

