-- lesson_ai_summaries: cache for AI-generated lesson summaries (patient + PT)
-- One row per (lesson_id, patient_profile_id, audience). Edge Function reads/writes with service role.

create table if not exists rehab.lesson_ai_summaries (
  lesson_id uuid not null,
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  audience text not null check (audience in ('patient', 'pt')),
  patient_summary text,
  next_time_cue text,
  pt_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (lesson_id, patient_profile_id, audience)
);

comment on table rehab.lesson_ai_summaries is 'Cached AI summaries per lesson/patient/audience; written by Edge Function after OpenAI call';

create index if not exists idx_lesson_ai_summaries_lookup
  on rehab.lesson_ai_summaries (lesson_id, patient_profile_id, audience);

alter table rehab.lesson_ai_summaries enable row level security;

-- Patients can select/insert/update their own rows
create policy lesson_ai_summaries_patient_select
  on rehab.lesson_ai_summaries for select
  to authenticated
  using (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

create policy lesson_ai_summaries_patient_insert
  on rehab.lesson_ai_summaries for insert
  to authenticated
  with check (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

create policy lesson_ai_summaries_patient_update
  on rehab.lesson_ai_summaries for update
  to authenticated
  using (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

-- PTs can select rows for their linked patients
create policy lesson_ai_summaries_pt_select
  on rehab.lesson_ai_summaries for select
  to authenticated
  using (patient_profile_id in (
    select m.patient_profile_id from accounts.pt_patient_map m
    inner join accounts.pt_profiles pp on pp.id = m.pt_profile_id
    inner join accounts.profiles p on p.id = pp.profile_id
    where p.user_id = auth.uid()
  ));

grant select, insert, update on rehab.lesson_ai_summaries to authenticated;
grant select, insert, update on rehab.lesson_ai_summaries to service_role;
