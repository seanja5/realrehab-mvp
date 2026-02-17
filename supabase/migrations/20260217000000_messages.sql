-- Messages between PT and patient. Thread = (pt_profile_id, patient_profile_id).
create table if not exists accounts.messages (
  id uuid primary key default gen_random_uuid(),
  pt_profile_id uuid not null references accounts.pt_profiles(id) on delete cascade,
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  sender_role text not null check (sender_role in ('pt', 'patient')),
  sender_display_name text,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_thread
  on accounts.messages(pt_profile_id, patient_profile_id, created_at desc);

alter table accounts.messages enable row level security;

-- PT can select messages for their patients
create policy messages_select_pt
  on accounts.messages for select to authenticated
  using (
    pt_profile_id in (
      select pt_profiles.id from accounts.pt_profiles
      join accounts.profiles on profiles.id = pt_profiles.profile_id
      where profiles.user_id = auth.uid()
    )
  );

-- Patient can select messages for their own threads
create policy messages_select_patient
  on accounts.messages for select to authenticated
  using (
    patient_profile_id in (
      select patient_profiles.id from accounts.patient_profiles
      join accounts.profiles on profiles.id = patient_profiles.profile_id
      where profiles.user_id = auth.uid()
    )
  );

-- PT can insert when they are the pt_profile_id
create policy messages_insert_pt
  on accounts.messages for insert to authenticated
  with check (
    sender_role = 'pt' and
    pt_profile_id in (
      select pt_profiles.id from accounts.pt_profiles
      join accounts.profiles on profiles.id = pt_profiles.profile_id
      where profiles.user_id = auth.uid()
    )
  );

-- Patient can insert when they are the patient_profile_id
create policy messages_insert_patient
  on accounts.messages for insert to authenticated
  with check (
    sender_role = 'patient' and
    patient_profile_id in (
      select patient_profiles.id from accounts.patient_profiles
      join accounts.profiles on profiles.id = patient_profiles.profile_id
      where profiles.user_id = auth.uid()
    )
  );

grant select, insert on accounts.messages to authenticated;

-- Add notify_messages to pt_profiles
alter table accounts.pt_profiles
  add column if not exists notify_messages boolean not null default true;

-- Add notify_messages to patient_profiles
alter table accounts.patient_profiles
  add column if not exists notify_messages boolean not null default true;
