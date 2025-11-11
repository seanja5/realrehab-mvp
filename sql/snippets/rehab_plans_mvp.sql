BEGIN;

-- Plans (one active plan per patient for MVP)
CREATE TABLE IF NOT EXISTS accounts.rehab_plans (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  pt_profile_id uuid NOT NULL REFERENCES accounts.pt_profiles(id) ON DELETE CASCADE,
  patient_profile_id uuid NOT NULL REFERENCES accounts.patient_profiles(id) ON DELETE CASCADE,
  category text NOT NULL,  -- e.g., "Knee"
  injury   text NOT NULL,  -- e.g., "ACL"
  status   text NOT NULL DEFAULT 'active', -- 'active' or 'archived'
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enforce one active plan per patient (unique partial index)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'accounts'
      AND indexname = 'uniq_active_plan_per_patient'
  ) THEN
    CREATE UNIQUE INDEX uniq_active_plan_per_patient
      ON accounts.rehab_plans (patient_profile_id)
      WHERE (status = 'active');
  END IF;
END $$;

-- Ensure patient_profiles has nullable profile_id (if not already)
ALTER TABLE accounts.patient_profiles
  ADD COLUMN IF NOT EXISTS profile_id uuid;

-- (Optional) phone column if not present
ALTER TABLE accounts.patient_profiles
  ADD COLUMN IF NOT EXISTS phone text;

NOTIFY pgrst, 'reload schema';
COMMIT;

