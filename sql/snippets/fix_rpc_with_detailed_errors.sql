-- Fix the RPC function with detailed error handling to see what's actually failing
-- This will help us identify the real issue

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
  v_error_detail text;
BEGIN
  -- Step 1: Get user ID
  BEGIN
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
      RAISE EXCEPTION 'Step 1 failed: No authenticated user found. This function must be called via PostgREST with an authenticated session.';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 1 error: %', SQLERRM;
  END;
  
  -- Step 2: Get patient profile
  BEGIN
    SELECT pp.id INTO v_patient_profile_id
    FROM accounts.patient_profiles pp
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE p.user_id = v_current_user_id
    LIMIT 1;
    
    IF v_patient_profile_id IS NULL THEN
      RAISE EXCEPTION 'Step 2 failed: No patient profile found for user_id: %', v_current_user_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 2 error: %', SQLERRM;
  END;
  
  -- Step 3: Get or create device
  BEGIN
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
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 3 error (device get/create): %', SQLERRM;
  END;
  
  -- Step 4: Get PT profile ID
  BEGIN
    SELECT ptm.pt_profile_id INTO v_pt_profile_id
    FROM accounts.pt_patient_map ptm
    WHERE ptm.patient_profile_id = v_patient_profile_id
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    -- PT profile ID can be NULL, so we'll just log and continue
    v_pt_profile_id := NULL;
  END;
  
  -- Step 5: Check if assignment exists
  BEGIN
    SELECT id INTO v_device_assignment_id
    FROM telemetry.device_assignments
    WHERE device_id = v_device_id
      AND patient_profile_id = v_patient_profile_id
      AND is_active = true
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 5 error (check existing assignment): %', SQLERRM;
  END;
  
  -- Step 6: Insert device assignment (THIS IS WHERE IT'S FAILING)
  IF v_device_assignment_id IS NULL THEN
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
      
      IF v_device_assignment_id IS NULL THEN
        RAISE EXCEPTION 'Step 6 failed: INSERT succeeded but returned NULL ID';
      END IF;
    EXCEPTION 
      WHEN insufficient_privilege THEN
        RAISE EXCEPTION 'Step 6 error (INSERT permission denied): Current user: %, Has INSERT: %, RLS enabled: %', 
          current_user, 
          has_table_privilege(current_user, 'telemetry.device_assignments', 'INSERT'),
          (SELECT rowsecurity FROM pg_tables WHERE schemaname = 'telemetry' AND tablename = 'device_assignments');
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Step 6 error (INSERT failed): % (SQLSTATE: %). Current user: %, Device ID: %, Patient Profile ID: %, PT Profile ID: %', 
          SQLERRM, SQLSTATE, current_user, v_device_id, v_patient_profile_id, v_pt_profile_id;
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

GRANT EXECUTE ON FUNCTION public.get_or_create_device_assignment(text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

