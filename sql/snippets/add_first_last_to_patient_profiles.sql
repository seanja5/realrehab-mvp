BEGIN;

ALTER TABLE accounts.patient_profiles
  ADD COLUMN IF NOT EXISTS first_name text,
  ADD COLUMN IF NOT EXISTS last_name text;

NOTIFY pgrst, 'reload schema';

COMMIT;

