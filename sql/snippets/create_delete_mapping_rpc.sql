BEGIN;

-- RPC FUNCTION APPROACH: Create a function that PTs can call to delete mappings
-- This bypasses RLS issues by using SECURITY DEFINER

CREATE OR REPLACE FUNCTION accounts.delete_pt_patient_mapping(
    p_pt_profile_id UUID,
    p_patient_profile_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = accounts, public
AS $$
DECLARE
    v_current_user_id UUID;
    v_pt_profile_id UUID;
BEGIN
    -- Get current user
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;
    
    -- Verify the PT profile belongs to the current user
    SELECT ptp.id INTO v_pt_profile_id
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = p_pt_profile_id
      AND p.user_id = v_current_user_id;
    
    IF v_pt_profile_id IS NULL THEN
        RAISE EXCEPTION 'PT profile does not belong to current user';
    END IF;
    
    -- Delete the mapping
    DELETE FROM accounts.pt_patient_map
    WHERE pt_profile_id = p_pt_profile_id
      AND patient_profile_id = p_patient_profile_id;
    
    -- Also clear access_code in patient_profiles (optional cleanup)
    UPDATE accounts.patient_profiles
    SET access_code = NULL
    WHERE id = p_patient_profile_id;
    
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION accounts.delete_pt_patient_mapping(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

