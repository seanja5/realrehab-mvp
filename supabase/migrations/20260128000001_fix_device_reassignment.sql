-- ============================================================================
-- FORWARD MIGRATION: Fix device reassignment to support multiple users over time
-- ============================================================================
-- Problem: When a different patient tries to use the same physical device,
-- the unique constraint "uniq_device_active_assignment" prevents the insert
-- because only one active assignment per device is allowed.
--
-- Solution: Modify get_or_create_device_assignment() to:
-- 1. Check if there's an active assignment for this device (any user)
-- 2. If it belongs to a different user, deactivate it (is_active=false, unpaired_at=now())
-- 3. Then create/return the active assignment for the current user
--
-- This preserves the constraint (one active assignment per device) while allowing
-- device reassignment over time.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_or_create_device_assignment(p_bluetooth_identifier text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'telemetry', 'accounts', 'public'
AS $function$
DECLARE
  v_device_id uuid;
  v_device_assignment_id uuid;
  v_patient_profile_id uuid;
  v_pt_profile_id uuid;
  v_current_user_id uuid;
  v_existing_assignment_id uuid;
  v_existing_patient_profile_id uuid;
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
  
  -- Step 5: Check if assignment exists for current user
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
  
  -- Step 6: If no assignment for current user, check for ANY active assignment on this device
  -- If it belongs to a different user, deactivate it first
  IF v_device_assignment_id IS NULL THEN
    BEGIN
      -- Check if there's an active assignment for this device (any user)
      SELECT id, patient_profile_id INTO v_existing_assignment_id, v_existing_patient_profile_id
      FROM telemetry.device_assignments
      WHERE device_id = v_device_id
        AND is_active = true
      LIMIT 1;
      
      -- If found and it belongs to a different user, deactivate it
      IF v_existing_assignment_id IS NOT NULL AND v_existing_patient_profile_id != v_patient_profile_id THEN
        UPDATE telemetry.device_assignments
        SET is_active = false,
            unpaired_at = now(),
            updated_at = now()
        WHERE id = v_existing_assignment_id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Step 6 error (check/deactivate existing assignment): %', SQLERRM;
    END;
    
    -- Step 7: Create new active assignment for current user
    BEGIN
      INSERT INTO telemetry.device_assignments (
        device_id,
        patient_profile_id,
        pt_profile_id,
        is_active,
        paired_at
      ) VALUES (
        v_device_id,
        v_patient_profile_id,
        v_pt_profile_id,
        true,
        now()
      ) RETURNING id INTO v_device_assignment_id;
      
      IF v_device_assignment_id IS NULL THEN
        RAISE EXCEPTION 'Step 7 failed: INSERT succeeded but returned NULL ID';
      END IF;
    EXCEPTION 
      WHEN unique_violation THEN
        -- This should not happen if we deactivated correctly, but handle gracefully
        RAISE EXCEPTION 'Step 7 error (unique constraint violation): Another active assignment exists for this device. This should have been deactivated.';
      WHEN insufficient_privilege THEN
        RAISE EXCEPTION 'Step 7 error (INSERT permission denied): Current user: %, Has INSERT: %, RLS enabled: %', 
          current_user, 
          has_table_privilege(current_user, 'telemetry.device_assignments', 'INSERT'),
          (SELECT rowsecurity FROM pg_tables WHERE schemaname = 'telemetry' AND tablename = 'device_assignments');
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Step 7 error (INSERT failed): % (SQLSTATE: %). Current user: %, Device ID: %, Patient Profile ID: %, PT Profile ID: %', 
          SQLERRM, SQLSTATE, current_user, v_device_id, v_patient_profile_id, v_pt_profile_id;
    END;
  END IF;
  
  RETURN v_device_assignment_id;
END;
$function$
;

-- Add comment to document the behavior
COMMENT ON FUNCTION public.get_or_create_device_assignment(text) IS 
  'Gets or creates a device assignment for the current user. If the device is already assigned to a different user, that assignment is automatically deactivated before creating a new one. This allows device reassignment over time while maintaining the constraint of one active assignment per device.';

