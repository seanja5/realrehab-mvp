-- RPC Function: Get PT Profile ID by Access Code
-- This function allows patients to find their PT when linking via access code
-- It bypasses RLS to return the PT profile ID for a valid access code
-- 
-- REVERSIBLE: To revert, simply run: DROP FUNCTION IF EXISTS public.get_pt_profile_id_by_access_code(text);

BEGIN;

-- Drop function from accounts schema if it exists (cleanup from previous version)
DROP FUNCTION IF EXISTS accounts.get_pt_profile_id_by_access_code(text) CASCADE;

-- Create the RPC function in public schema (PostgREST looks here by default)
CREATE OR REPLACE FUNCTION public.get_pt_profile_id_by_access_code(access_code_param text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
DECLARE
  placeholder_id uuid;
  pt_profile_id_result uuid;
BEGIN
  -- Step 1: Find the placeholder patient profile by access code
  -- Only look for placeholders (profile_id IS NULL) that haven't been linked yet
  SELECT id INTO placeholder_id
  FROM accounts.patient_profiles
  WHERE access_code = access_code_param
    AND profile_id IS NULL
  LIMIT 1;
  
  -- If no placeholder found, return NULL
  IF placeholder_id IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Step 2: Get the PT profile ID from pt_patient_map
  SELECT pt_profile_id INTO pt_profile_id_result
  FROM accounts.pt_patient_map
  WHERE patient_profile_id = placeholder_id
  LIMIT 1;
  
  -- Return the PT profile ID (or NULL if not found)
  RETURN pt_profile_id_result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_pt_profile_id_by_access_code(text) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.get_pt_profile_id_by_access_code(text) IS 
  'Returns the PT profile ID for a given access code. Used when patients link their account to a PT after account creation. Returns NULL if access code is invalid or placeholder not found.';

-- Verify the function was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'get_pt_profile_id_by_access_code'
  ) THEN
    RAISE EXCEPTION 'Function get_pt_profile_id_by_access_code was not created';
  END IF;
  
  RAISE NOTICE 'Function get_pt_profile_id_by_access_code created successfully in public schema';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- REVERSAL SCRIPT (run this to revert):
-- DROP FUNCTION IF EXISTS public.get_pt_profile_id_by_access_code(text);

