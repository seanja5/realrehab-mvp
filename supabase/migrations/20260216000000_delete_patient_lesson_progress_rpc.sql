-- RPC to delete one lesson's progress for the current patient (e.g. when they "restart" the lesson).
-- Uses same session resolution as upsert so progress is actually removed and PT sees the update.
create or replace function accounts.delete_patient_lesson_progress(p_lesson_id uuid)
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

  delete from accounts.patient_lesson_progress
  where patient_profile_id = v_patient_profile_id
    and lesson_id = p_lesson_id;
end;
$$;

grant execute on function accounts.delete_patient_lesson_progress(uuid) to authenticated;
