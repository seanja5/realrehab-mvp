-- Patient schedule slots: personalized weekly schedule per patient profile
-- Each slot represents a 30-minute block (day_of_week + slot_time = start time)
-- Used for "My Schedule" visualizer and future reminder notifications

create table if not exists accounts.patient_schedule_slots (
  id uuid primary key default gen_random_uuid(),
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  slot_time time without time zone not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_patient_schedule_slots_patient on accounts.patient_schedule_slots(patient_profile_id);
create index if not exists idx_patient_schedule_slots_day on accounts.patient_schedule_slots(day_of_week);

-- RLS
alter table accounts.patient_schedule_slots enable row level security;

-- Patients can only access their own schedule slots
create policy patient_schedule_slots_select_own
  on accounts.patient_schedule_slots
  for select
  using (
    accounts.is_admin()
    or (accounts.is_patient() and patient_profile_id = accounts.current_patient_profile_id())
    or (accounts.is_pt() and accounts.is_pt_assigned_to(patient_profile_id))
  );

create policy patient_schedule_slots_insert_own
  on accounts.patient_schedule_slots
  for insert
  with check (
    accounts.is_admin()
    or (accounts.is_patient() and patient_profile_id = accounts.current_patient_profile_id())
  );

create policy patient_schedule_slots_update_own
  on accounts.patient_schedule_slots
  for update
  using (
    accounts.is_admin()
    or (accounts.is_patient() and patient_profile_id = accounts.current_patient_profile_id())
  )
  with check (
    accounts.is_admin()
    or (accounts.is_patient() and patient_profile_id = accounts.current_patient_profile_id())
  );

create policy patient_schedule_slots_delete_own
  on accounts.patient_schedule_slots
  for delete
  using (
    accounts.is_admin()
    or (accounts.is_patient() and patient_profile_id = accounts.current_patient_profile_id())
  );

-- Grant permissions
grant select, insert, update, delete on table accounts.patient_schedule_slots to authenticated;
