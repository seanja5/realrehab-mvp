-- Add schedule_reminders_enabled to patient_profiles (patient-level preference)
-- Default false. Do NOT add reminder flag to patient_schedule_slots.
alter table accounts.patient_profiles
  add column if not exists schedule_reminders_enabled boolean not null default false;
