-- Add dark_mode_enabled to accounts.profiles (shared across all roles)
-- Default false (light mode). Persists user's appearance preference across devices.
alter table accounts.profiles
  add column if not exists dark_mode_enabled boolean not null default false;
