BEGIN;

-- Drop function if it exists (in both public and accounts schemas for cleanup)
DROP FUNCTION IF EXISTS public.add_patient_with_mapping(text, text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS accounts.add_patient_with_mapping(text, text, text, text, uuid) CASCADE;

-- Create SECURITY DEFINER function in public schema so PostgREST can call it via RPC
-- This function creates a patient profile placeholder AND the pt_patient_map entry
-- It bypasses RLS, which is safe because:
-- 1. It validates that the pt_profile_id belongs to the current user
-- 2. It only creates placeholder patient profiles (profile_id = NULL)
CREATE OR REPLACE FUNCTION public.add_patient_with_mapping(
  p_first_name text,
  p_last_name text,
  p_date_of_birth text,
  p_gender text,
  p_pt_profile_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
DECLARE
  v_patient_id uuid;
  v_current_user_id uuid;
BEGIN
  -- Get current user ID
  v_current_user_id := auth.uid();
  
  -- Verify that the PT profile belongs to the current user
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = p_pt_profile_id
      AND p.user_id = v_current_user_id
  ) THEN
    RAISE EXCEPTION 'PT profile does not belong to current user';
  END IF;
  
  -- Create patient profile placeholder
  INSERT INTO accounts.patient_profiles (
    profile_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    access_code
  ) VALUES (
    NULL,  -- Explicitly NULL (placeholder)
    p_first_name,
    p_last_name,
    p_date_of_birth::date,  -- Cast text to date (ISO8601 format YYYY-MM-DD)
    p_gender::accounts.gender,  -- Cast text to accounts.gender enum
    accounts.generate_unique_access_code()  -- Generate unique 8-digit access code
  ) RETURNING id INTO v_patient_id;
  
  -- Create pt_patient_map entry
  INSERT INTO accounts.pt_patient_map (
    patient_profile_id,
    pt_profile_id
  ) VALUES (
    v_patient_id,
    p_pt_profile_id
  )
  ON CONFLICT (patient_profile_id) DO UPDATE
  SET pt_profile_id = p_pt_profile_id;
  
  RETURN v_patient_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.add_patient_with_mapping(text, text, text, text, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

