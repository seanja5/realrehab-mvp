-- RPC Function: Link Patient to PT via Access Code
-- This function handles the complete linking process:
-- 1. Finds placeholder by access code
-- 2. Updates placeholder with patient's profile_id and data
-- 3. Ensures pt_patient_map points to the updated placeholder
-- 4. Deletes any duplicate mappings
-- 
-- REVERSIBLE: To revert, simply run: DROP FUNCTION IF EXISTS public.link_patient_via_access_code(text, uuid);

BEGIN;

-- Create the RPC function in public schema (PostgREST looks here by default)
CREATE OR REPLACE FUNCTION public.link_patient_via_access_code(
  access_code_param text,
  patient_profile_id_param uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
DECLARE
  placeholder_id uuid;
  pt_profile_id_result uuid;
  current_profile_id uuid;
  patient_first_name text;
  patient_last_name text;
  patient_phone text;
  patient_dob text;
  patient_gender text;
BEGIN
  -- Step 1: Verify that the patient_profile_id belongs to the current user
  SELECT profile_id INTO current_profile_id
  FROM accounts.patient_profiles
  WHERE id = patient_profile_id_param;
  
  IF current_profile_id IS NULL THEN
    RAISE EXCEPTION 'Patient profile not found';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.profiles
    WHERE id = current_profile_id
      AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Patient profile does not belong to current user';
  END IF;
  
  -- Step 2: Find placeholder by access code
  SELECT id INTO placeholder_id
  FROM accounts.patient_profiles
  WHERE access_code = access_code_param
    AND profile_id IS NULL
  LIMIT 1;
  
  IF placeholder_id IS NULL THEN
    RAISE EXCEPTION 'Invalid access code';
  END IF;
  
  -- Step 3: Get PT profile ID from the placeholder's mapping
  SELECT pt_profile_id INTO pt_profile_id_result
  FROM accounts.pt_patient_map
  WHERE patient_profile_id = placeholder_id
  LIMIT 1;
  
  IF pt_profile_id_result IS NULL THEN
    RAISE EXCEPTION 'No Physical Therapist found for this access code';
  END IF;
  
  -- Step 4: Get patient's data from their existing profile
  -- Cast date_of_birth and gender to text to ensure type consistency
  SELECT first_name, last_name, phone, date_of_birth::text, gender::text
  INTO patient_first_name, patient_last_name, patient_phone, patient_dob, patient_gender
  FROM accounts.patient_profiles
  WHERE id = patient_profile_id_param;
  
  -- Step 5: Delete the original patient_profiles row FIRST (before updating placeholder)
  -- This prevents unique constraint violation on profile_id
  -- Only delete if it's different from the placeholder
  IF patient_profile_id_param != placeholder_id THEN
    DELETE FROM accounts.patient_profiles
    WHERE id = patient_profile_id_param
      AND profile_id = current_profile_id;
  END IF;
  
  -- Step 6: Update the placeholder with patient's profile_id and data
  -- Use CASE to handle date_of_birth and gender properly (cast to correct types)
  UPDATE accounts.patient_profiles
  SET 
    profile_id = current_profile_id,
    first_name = COALESCE(patient_first_name, first_name),
    last_name = COALESCE(patient_last_name, last_name),
    phone = COALESCE(patient_phone, phone),
    date_of_birth = CASE 
      WHEN patient_dob IS NOT NULL THEN patient_dob::date
      ELSE date_of_birth
    END,
    gender = CASE 
      WHEN patient_gender IS NOT NULL THEN patient_gender::accounts.gender
      ELSE gender
    END
  WHERE id = placeholder_id;
  
  -- Step 7: Update pt_patient_map to point to placeholder (if it doesn't already)
  -- This ensures the mapping uses the placeholder ID (which now has profile_id set)
  INSERT INTO accounts.pt_patient_map (patient_profile_id, pt_profile_id)
  VALUES (placeholder_id, pt_profile_id_result)
  ON CONFLICT (patient_profile_id)
  DO UPDATE SET pt_profile_id = pt_profile_id_result;
  
  -- Step 8: Delete any duplicate mapping that might point to the real patient_profile_id
  -- (in case one was created before this function was called)
  DELETE FROM accounts.pt_patient_map
  WHERE patient_profile_id = patient_profile_id_param
    AND patient_profile_id != placeholder_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.link_patient_via_access_code(text, uuid) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.link_patient_via_access_code(text, uuid) IS 
  'Links a patient to a PT by updating the placeholder created by the PT. Updates placeholder with patient profile_id and data, ensuring no duplicates.';

-- Verify the function was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'link_patient_via_access_code'
  ) THEN
    RAISE EXCEPTION 'Function link_patient_via_access_code was not created';
  END IF;
  
  RAISE NOTICE 'Function link_patient_via_access_code created successfully in public schema';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- REVERSAL SCRIPT (run this to revert):
-- DROP FUNCTION IF EXISTS public.link_patient_via_access_code(text, uuid);

