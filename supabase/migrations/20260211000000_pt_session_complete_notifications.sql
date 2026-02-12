-- PT notification preferences and session-complete events for "Patient session completed" toggle.
-- When a patient completes a lesson (reaches Completion screen), we insert an event so the PT can be notified.

-- Add notification preference columns to pt_profiles
alter table accounts.pt_profiles
  add column if not exists notify_session_complete boolean not null default true,
  add column if not exists notify_missed_day boolean not null default false;

-- Table of session-complete events (one row per patient completion; PT can subscribe via Realtime)
create table if not exists accounts.pt_session_complete_events (
  id uuid primary key default gen_random_uuid(),
  pt_profile_id uuid not null references accounts.pt_profiles(id) on delete cascade,
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  patient_first_name text,
  patient_last_name text,
  lesson_id uuid not null,
  lesson_title text,
  created_at timestamptz not null default now()
);

alter table accounts.pt_session_complete_events enable row level security;

-- PT can only select their own events
create policy pt_session_complete_events_select_owner
  on accounts.pt_session_complete_events
  for select
  to authenticated
  using (
    pt_profile_id in (
      select pt_profiles.id
      from accounts.pt_profiles
      join accounts.profiles on profiles.id = pt_profiles.profile_id
      where profiles.user_id = auth.uid()
    )
  );

-- Insert is done via RPC (patient calls it; RPC runs as definer)
-- No direct insert policy for authenticated; the function inserts.

grant select on accounts.pt_session_complete_events to authenticated;

-- RPC: patient calls this when they complete a lesson. If the PT has notify_session_complete = true, inserts an event.
create or replace function public.notify_pt_session_complete(
  p_patient_profile_id uuid,
  p_lesson_id uuid,
  p_lesson_title text default 'Lesson'
)
returns void
language plpgsql
security definer
set search_path = public, accounts
as $$
declare
  v_pt_profile_id uuid;
  v_notify boolean;
  v_first text;
  v_last text;
begin
  select pt_profile_id into v_pt_profile_id
  from accounts.pt_patient_map
  where patient_profile_id = p_patient_profile_id
  limit 1;
  if v_pt_profile_id is null then
    return;
  end if;

  select coalesce(notify_session_complete, true) into v_notify
  from accounts.pt_profiles
  where id = v_pt_profile_id;
  if not v_notify then
    return;
  end if;

  select first_name, last_name into v_first, v_last
  from accounts.patient_profiles
  where id = p_patient_profile_id;

  insert into accounts.pt_session_complete_events (
    pt_profile_id, patient_profile_id, patient_first_name, patient_last_name, lesson_id, lesson_title
  ) values (
    v_pt_profile_id, p_patient_profile_id, v_first, v_last, p_lesson_id, coalesce(nullif(trim(p_lesson_title), ''), 'Lesson')
  );
end;
$$;

grant execute on function public.notify_pt_session_complete(uuid, uuid, text) to authenticated;

comment on table accounts.pt_session_complete_events is 'One row per patient lesson completion; PT subscribes via Realtime to show notifications.';
comment on function public.notify_pt_session_complete is 'Called by patient app when they reach Completion screen; inserts event if PT has notify_session_complete enabled.';

-- Optional: enable Realtime for this table so PT app can subscribe to live inserts.
-- Uncomment and run if using Supabase Realtime (add table to supabase_realtime publication):
-- alter publication supabase_realtime add table accounts.pt_session_complete_events;
