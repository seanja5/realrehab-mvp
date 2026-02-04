-- patient_lesson_progress: per-patient, per-lesson (plan node) progress for offline resume + sync
-- Uses accounts.current_patient_profile_id() which exists in schema
create table if not exists accounts.patient_lesson_progress (
  id uuid primary key default gen_random_uuid(),
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  lesson_id uuid not null,
  reps_completed integer not null default 0,
  reps_target integer not null,
  elapsed_seconds integer not null default 0,
  status text not null default 'inProgress' check (status in ('inProgress', 'completed')),
  updated_at timestamptz not null default now(),
  unique (patient_profile_id, lesson_id)
);

create index if not exists idx_patient_lesson_progress_patient
  on accounts.patient_lesson_progress(patient_profile_id);

alter table accounts.patient_lesson_progress enable row level security;

create policy patient_lesson_progress_select_own
  on accounts.patient_lesson_progress for select
  using (patient_profile_id = accounts.current_patient_profile_id());

create policy patient_lesson_progress_insert_own
  on accounts.patient_lesson_progress for insert
  with check (patient_profile_id = accounts.current_patient_profile_id());

create policy patient_lesson_progress_update_own
  on accounts.patient_lesson_progress for update
  using (patient_profile_id = accounts.current_patient_profile_id());

grant select, insert, update on accounts.patient_lesson_progress to authenticated;
