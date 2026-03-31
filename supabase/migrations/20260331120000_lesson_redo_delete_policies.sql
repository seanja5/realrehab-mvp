-- Allow patients to delete their own lesson_sensor_insights and lesson_ai_summaries rows (re-do lesson flow).

-- lesson_sensor_insights
create policy lesson_sensor_insights_patient_delete
  on rehab.lesson_sensor_insights for delete
  to authenticated
  using (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

grant delete on rehab.lesson_sensor_insights to authenticated;

-- lesson_ai_summaries (cached AI text per lesson/patient/audience)
create policy lesson_ai_summaries_patient_delete
  on rehab.lesson_ai_summaries for delete
  to authenticated
  using (patient_profile_id in (
    select pat.id from accounts.patient_profiles pat
    inner join accounts.profiles p on pat.profile_id = p.id
    where p.user_id = auth.uid()
  ));

grant delete on rehab.lesson_ai_summaries to authenticated;
