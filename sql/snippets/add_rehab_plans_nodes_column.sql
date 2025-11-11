BEGIN;

-- Add nodes JSONB column to accounts.rehab_plans
-- Stores array of plan nodes with: id (UUID string), title, icon, isLocked, reps, restSec
ALTER TABLE accounts.rehab_plans
  ADD COLUMN IF NOT EXISTS nodes jsonb;

-- No indexes initially (can add GIN index later if querying needed)
-- Example for future: CREATE INDEX IF NOT EXISTS idx_rehab_plans_nodes_gin ON accounts.rehab_plans USING GIN (nodes);

NOTIFY pgrst, 'reload schema';
COMMIT;

