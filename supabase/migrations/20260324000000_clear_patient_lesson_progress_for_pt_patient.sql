-- PT-only: delete all lesson progress for a patient when assigning a new rehab plan
-- (lesson_ids can repeat across plans, so rows must be cleared explicitly).
create or replace function accounts.clear_patient_lesson_progress_for_pt_patient(
  p_pt_profile_id uuid,
  p_patient_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = accounts, public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not accounts.is_pt() then
    raise exception 'Only physical therapists can clear lesson progress';
  end if;

  if accounts.current_pt_profile_id() is distinct from p_pt_profile_id then
    raise exception 'PT profile mismatch';
  end if;

  if not exists (
    select 1
    from accounts.pt_patient_map m
    where m.pt_profile_id = p_pt_profile_id
      and m.patient_profile_id = p_patient_profile_id
  ) then
    raise exception 'Patient is not assigned to this PT';
  end if;

  delete from accounts.patient_lesson_progress
  where patient_profile_id = p_patient_profile_id;
end;
$$;

grant execute on function accounts.clear_patient_lesson_progress_for_pt_patient(uuid, uuid) to authenticated;
