BEGIN;

-- Create function to generate unique 8-digit access codes
-- Returns a random 8-digit numeric string (00000000-99999999)
-- Ensures uniqueness by checking against existing codes
CREATE OR REPLACE FUNCTION accounts.generate_unique_access_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_code text;
  v_exists boolean;
  v_attempts int := 0;
  v_max_attempts int := 100;
BEGIN
  LOOP
    -- Generate random 8-digit code (padded with zeros)
    v_code := LPAD(FLOOR(RANDOM() * 100000000)::text, 8, '0');
    
    -- Check if code already exists
    SELECT EXISTS(
      SELECT 1 
      FROM accounts.patient_profiles 
      WHERE access_code = v_code
    ) INTO v_exists;
    
    -- If code doesn't exist, return it
    EXIT WHEN NOT v_exists;
    
    -- Safety check to prevent infinite loop
    v_attempts := v_attempts + 1;
    IF v_attempts >= v_max_attempts THEN
      RAISE EXCEPTION 'Failed to generate unique access code after % attempts', v_max_attempts;
    END IF;
  END LOOP;
  
  RETURN v_code;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION accounts.generate_unique_access_code() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION accounts.generate_unique_access_code() IS 'Generates a unique 8-digit numeric access code for patient profiles';

NOTIFY pgrst, 'reload schema';

COMMIT;
