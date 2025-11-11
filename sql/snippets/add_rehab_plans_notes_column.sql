BEGIN;

-- Add notes text column to accounts.rehab_plans
-- Stores PT notes for specific patients
ALTER TABLE accounts.rehab_plans
  ADD COLUMN IF NOT EXISTS notes text;

NOTIFY pgrst, 'reload schema';
COMMIT;

