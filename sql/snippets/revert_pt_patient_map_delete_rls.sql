BEGIN;

-- REVERSE MIGRATION: Revert pt_patient_map DELETE policy changes
-- This will restore the DELETE policy to its previous state
-- Note: This assumes the policy existed before. If it didn't exist, this will just drop it.

-- Drop the DELETE policy we created
DROP POLICY IF EXISTS pt_patient_map_delete_owner ON accounts.pt_patient_map;

-- If you had a different DELETE policy before, you would recreate it here
-- For now, this just removes the policy (which means no one can delete, which is safe)

NOTIFY pgrst, 'reload schema';

COMMIT;

