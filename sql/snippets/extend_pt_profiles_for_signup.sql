BEGIN;

-- Ensure required/optional PT columns exist on accounts.pt_profiles
ALTER TABLE accounts.pt_profiles
  ADD COLUMN IF NOT EXISTS license_number text,
  ADD COLUMN IF NOT EXISTS npi_number text,
  ADD COLUMN IF NOT EXISTS practice_name text,
  ADD COLUMN IF NOT EXISTS practice_address text,
  ADD COLUMN IF NOT EXISTS specialization text;

-- Optional: make email unique if not already
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'pt_profiles_email_unique'
       AND conrelid = 'accounts.pt_profiles'::regclass
  ) THEN
    ALTER TABLE accounts.pt_profiles
      ADD CONSTRAINT pt_profiles_email_unique UNIQUE (email);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

