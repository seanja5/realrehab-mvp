BEGIN;

-- Retroactively generate access codes for existing patients
-- This updates all rows where access_code IS NULL
UPDATE accounts.patient_profiles
SET access_code = accounts.generate_unique_access_code()
WHERE access_code IS NULL;

-- After populating all existing rows, we can optionally make the column NOT NULL
-- Uncomment the following lines if you want to enforce NOT NULL:
-- ALTER TABLE accounts.patient_profiles 
-- ALTER COLUMN access_code SET NOT NULL;

-- Note: We're keeping it nullable for now to allow flexibility
-- New inserts will always have codes, but we keep NULL allowed for edge cases

NOTIFY pgrst, 'reload schema';

COMMIT;
