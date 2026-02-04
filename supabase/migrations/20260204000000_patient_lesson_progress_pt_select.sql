-- Allow PTs to select their patients' lesson progress (for journey map)
create policy patient_lesson_progress_select_pt
  on accounts.patient_lesson_progress for select
  using (
    exists (
      select 1 from accounts.pt_patient_map m
      where m.patient_profile_id = patient_lesson_progress.patient_profile_id
        and m.pt_profile_id = accounts.current_pt_profile_id()
    )
  );
