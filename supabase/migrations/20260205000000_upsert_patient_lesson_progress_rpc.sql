-- RPC to upsert patient lesson progress. Bypasses RLS; uses session's patient_profile_id.
-- Ensures lesson progress is stored even when direct table access has RLS issues.
create or replace function accounts.upsert_patient_lesson_progress(
  p_lesson_id uuid,
  p_reps_completed integer,
  p_reps_target integer,
  p_elapsed_seconds integer,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = accounts, public
as $$
declare
  v_patient_profile_id uuid;
begin
  v_patient_profile_id := accounts.current_patient_profile_id();
  if v_patient_profile_id is null then
    raise exception 'Not authenticated as a patient';
  end if;

  if p_status not in ('inProgress', 'completed') then
    raise exception 'Invalid status: %', p_status;
  end if;

  insert into accounts.patient_lesson_progress (
    patient_profile_id,
    lesson_id,
    reps_completed,
    reps_target,
    elapsed_seconds,
    status,
    updated_at
  )
  values (
    v_patient_profile_id,
    p_lesson_id,
    p_reps_completed,
    p_reps_target,
    p_elapsed_seconds,
    p_status,
    now()
  )
  on conflict (patient_profile_id, lesson_id)
  do update set
    reps_completed = excluded.reps_completed,
    reps_target = excluded.reps_target,
    elapsed_seconds = excluded.elapsed_seconds,
    status = excluded.status,
    updated_at = now();
end;
$$;

grant execute on function accounts.upsert_patient_lesson_progress(uuid, integer, integer, integer, text) to authenticated;
