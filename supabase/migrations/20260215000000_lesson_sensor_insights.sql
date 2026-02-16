-- lesson_sensor_insights: per-lesson sensor data (IMU, events) for PT analytics
-- Linked to patient and PT so PTs can view their patients' lesson analytics.

create schema if not exists rehab;

create table if not exists rehab.lesson_sensor_insights (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null,
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  pt_profile_id uuid not null references accounts.pt_profiles(id) on delete cascade,
  started_at timestamptz not null,
  completed_at timestamptz,
  total_duration_sec integer not null default 0,
  reps_target integer not null,
  reps_completed integer not null,
  reps_attempted integer not null,
  events jsonb not null default '[]'::jsonb,
  imu_samples jsonb not null default '[]'::jsonb,
  shake_frequency_samples jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lesson_id, patient_profile_id)
);

comment on column rehab.lesson_sensor_insights.events is 'Array of {event_type, rep_attempt, time_sec}';
comment on column rehab.lesson_sensor_insights.imu_samples is 'Array of {time_ms, imu_value} at 100ms';
comment on column rehab.lesson_sensor_insights.shake_frequency_samples is 'Array of {time_ms, frequency}';

create index if not exists idx_lesson_sensor_insights_lesson_patient
  on rehab.lesson_sensor_insights (lesson_id, patient_profile_id);

create index if not exists idx_lesson_sensor_insights_pt
  on rehab.lesson_sensor_insights (pt_profile_id);

create index if not exists idx_lesson_sensor_insights_patient
  on rehab.lesson_sensor_insights (patient_profile_id);

alter table rehab.lesson_sensor_insights enable row level security;

-- Patients can select their own (via patient_profile_id)
create policy lesson_sensor_insights_patient_select
  on rehab.lesson_sensor_insights for select
  to authenticated
  using (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

-- PTs can select rows for their patients (via pt_profile_id)
create policy lesson_sensor_insights_pt_select
  on rehab.lesson_sensor_insights for select
  to authenticated
  using (pt_profile_id in (
    select pp.id from accounts.pt_profiles pp
    inner join accounts.profiles p on pp.profile_id = p.id
    where p.user_id = auth.uid()
  ));

-- Patients can insert/update their own (when lesson runs on patient device)
create policy lesson_sensor_insights_patient_insert
  on rehab.lesson_sensor_insights for insert
  to authenticated
  with check (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

create policy lesson_sensor_insights_patient_update
  on rehab.lesson_sensor_insights for update
  to authenticated
  using (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

grant select, insert, update on rehab.lesson_sensor_insights to authenticated;
