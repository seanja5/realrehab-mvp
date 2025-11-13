BEGIN;

-- Drop function if it exists (in both public and accounts schemas for cleanup)
DROP FUNCTION IF EXISTS public.insert_patient_profile_placeholder(text, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS accounts.insert_patient_profile_placeholder(text, text, text, text) CASCADE;

-- Create SECURITY DEFINER function in public schema so PostgREST can call it via RPC
-- This bypasses RLS, which is safe because function only allows NULL profile_id
CREATE OR REPLACE FUNCTION public.insert_patient_profile_placeholder(
  p_first_name text,
  p_last_name text,
  p_date_of_birth text,
  p_gender text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
DECLARE
  v_patient_id uuid;
BEGIN
  INSERT INTO accounts.patient_profiles (
    profile_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    access_code
  ) VALUES (
    NULL,  -- Explicitly NULL
    p_first_name,
    p_last_name,
    p_date_of_birth::date,  -- Cast text to date (ISO8601 format YYYY-MM-DD)
    p_gender::accounts.gender,  -- Cast text to accounts.gender enum
    accounts.generate_unique_access_code()  -- Generate unique 8-digit access code
  ) RETURNING id INTO v_patient_id;
  
  RETURN v_patient_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.insert_patient_profile_placeholder(text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

