-- RPC Function: Link Patient to PT
-- This function allows patients to create a mapping between their patient profile and a PT
-- It bypasses RLS to allow patients to link themselves to a PT using an access code
-- 
-- REVERSIBLE: To revert, simply run: DROP FUNCTION IF EXISTS public.link_patient_to_pt(uuid, uuid);

BEGIN;

-- Create the RPC function in public schema (PostgREST looks here by default)
CREATE OR REPLACE FUNCTION public.link_patient_to_pt(
  patient_profile_id_param uuid,
  pt_profile_id_param uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
BEGIN
  -- Verify that the patient_profile_id belongs to the current user
  -- This ensures patients can only link their own profile
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pat
    WHERE pat.id = patient_profile_id_param
      AND pat.profile_id IN (
        SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
      )
  ) THEN
    RAISE EXCEPTION 'Patient profile does not belong to current user';
  END IF;
  
  -- Verify that the PT profile exists
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles
    WHERE id = pt_profile_id_param
  ) THEN
    RAISE EXCEPTION 'PT profile not found';
  END IF;
  
  -- Insert or update the mapping (upsert)
  INSERT INTO accounts.pt_patient_map (patient_profile_id, pt_profile_id)
  VALUES (patient_profile_id_param, pt_profile_id_param)
  ON CONFLICT (patient_profile_id)
  DO UPDATE SET pt_profile_id = pt_profile_id_param;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.link_patient_to_pt(uuid, uuid) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.link_patient_to_pt(uuid, uuid) IS 
  'Links a patient profile to a PT profile. Can only be called by the patient who owns the patient_profile_id. Used when patients link their account to a PT after account creation.';

-- Verify the function was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'link_patient_to_pt'
  ) THEN
    RAISE EXCEPTION 'Function link_patient_to_pt was not created';
  END IF;
  
  RAISE NOTICE 'Function link_patient_to_pt created successfully in public schema';
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- REVERSAL SCRIPT (run this to revert):
-- DROP FUNCTION IF EXISTS public.link_patient_to_pt(uuid, uuid);

