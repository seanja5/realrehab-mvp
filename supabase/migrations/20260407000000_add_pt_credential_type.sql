-- Add pt_credential_type column to pt_profiles
-- Stores the PT's professional credential designation (PT, DPT, PTA, etc.)
ALTER TABLE accounts.pt_profiles
  ADD COLUMN IF NOT EXISTS pt_credential_type TEXT;
