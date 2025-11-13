drop policy "pt_profiles_select_owner" on "accounts"."pt_profiles";

drop policy "patient_profiles_select_owner" on "accounts"."patient_profiles";

drop policy "patient_profiles_update" on "accounts"."patient_profiles";


  create policy "pt_profiles_select_owner_or_mapped"
  on "accounts"."pt_profiles"
  as permissive
  for select
  to authenticated
using (((EXISTS ( SELECT 1
   FROM accounts.profiles p
  WHERE ((p.id = pt_profiles.profile_id) AND (p.user_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM ((accounts.pt_patient_map ptm
     JOIN accounts.patient_profiles pat ON ((ptm.patient_profile_id = pat.id)))
     JOIN accounts.profiles p ON ((pat.profile_id = p.id)))
  WHERE ((ptm.pt_profile_id = pt_profiles.id) AND (p.user_id = auth.uid()))))));



  create policy "patient_profiles_select_owner"
  on "accounts"."patient_profiles"
  as permissive
  for select
  to authenticated
using (((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR accounts.is_patient_mapped_to_current_pt(id)));



  create policy "patient_profiles_update"
  on "accounts"."patient_profiles"
  as permissive
  for update
  to authenticated
using (((profile_id IS NULL) OR (profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR accounts.is_patient_mapped_to_current_pt(id)))
with check (((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR accounts.is_patient_mapped_to_current_pt(id)));



