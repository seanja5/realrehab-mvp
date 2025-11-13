BEGIN;

-- Add access_code column to patient_profiles
-- Initially nullable to allow retroactive population of existing rows
ALTER TABLE accounts.patient_profiles 
ADD COLUMN IF NOT EXISTS access_code text;

-- Create unique index for fast lookups (deferrable to allow NULL values initially)
CREATE UNIQUE INDEX IF NOT EXISTS idx_patient_profiles_access_code 
ON accounts.patient_profiles(access_code) 
WHERE access_code IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN accounts.patient_profiles.access_code IS '8-digit unique access code for linking patients to PT accounts during signup';

NOTIFY pgrst, 'reload schema';

COMMIT;
