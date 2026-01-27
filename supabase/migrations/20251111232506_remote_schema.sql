drop policy "patient_profiles_insert_by_pt" on "accounts"."patient_profiles";

drop policy "patient_profiles_patient_self_select" on "accounts"."patient_profiles";

drop policy "patient_profiles_patient_self_update" on "accounts"."patient_profiles";

drop policy "patient_profiles_pt_owner_select" on "accounts"."patient_profiles";

drop policy "patient_profiles_pt_owner_update" on "accounts"."patient_profiles";

drop policy "pt_patient_map_delete_owner" on "accounts"."pt_patient_map";

drop policy "pt_patient_map_insert_owner" on "accounts"."pt_patient_map";

drop policy "pt_patient_map_select_owner" on "accounts"."pt_patient_map";

drop policy "pt_patient_map_update_owner" on "accounts"."pt_patient_map";

drop table "accounts"."pt_profiles_backup_20251109";

alter table "accounts"."rehab_plans" add column "nodes" jsonb;

alter table "accounts"."rehab_plans" add column "notes" text;

alter table "accounts"."rehab_plans" enable row level security;

CREATE INDEX idx_rehab_plans_pt_patient ON accounts.rehab_plans USING btree (pt_profile_id, patient_profile_id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION accounts.is_patient_owned(patient_profile_id_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pat
    INNER JOIN accounts.profiles p ON pat.profile_id = p.id
    WHERE pat.id = patient_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_pt_owned(pt_profile_id_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles pp
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE pp.id = pt_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$function$
;

grant delete on table "accounts"."rehab_plans" to "authenticated";

grant insert on table "accounts"."rehab_plans" to "authenticated";

grant select on table "accounts"."rehab_plans" to "authenticated";

grant update on table "accounts"."rehab_plans" to "authenticated";


  create policy "patient_profiles_delete"
  on "accounts"."patient_profiles"
  as permissive
  for delete
  to authenticated
using ((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))));



  create policy "patient_profiles_insert_null"
  on "accounts"."patient_profiles"
  as permissive
  for insert
  to authenticated
with check ((profile_id IS NULL));



  create policy "patient_profiles_insert_own"
  on "accounts"."patient_profiles"
  as permissive
  for insert
  to authenticated
with check ((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))));



  create policy "patient_profiles_select_owner"
  on "accounts"."patient_profiles"
  as permissive
  for select
  to authenticated
using (((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM ((accounts.pt_patient_map ptm
     JOIN accounts.pt_profiles pp ON ((ptm.pt_profile_id = pp.id)))
     JOIN accounts.profiles p ON ((pp.profile_id = p.id)))
  WHERE ((ptm.patient_profile_id = patient_profiles.id) AND (p.user_id = auth.uid()))))));



  create policy "patient_profiles_update"
  on "accounts"."patient_profiles"
  as permissive
  for update
  to authenticated
using (((profile_id IS NULL) OR (profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM ((accounts.pt_patient_map ptm
     JOIN accounts.pt_profiles pp ON ((ptm.pt_profile_id = pp.id)))
     JOIN accounts.profiles p ON ((pp.profile_id = p.id)))
  WHERE ((ptm.patient_profile_id = patient_profiles.id) AND (p.user_id = auth.uid()))))))
with check (((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM ((accounts.pt_patient_map ptm
     JOIN accounts.pt_profiles pp ON ((ptm.pt_profile_id = pp.id)))
     JOIN accounts.profiles p ON ((pp.profile_id = p.id)))
  WHERE ((ptm.patient_profile_id = patient_profiles.id) AND (p.user_id = auth.uid()))))));



  create policy "rehab_plans_delete_owner"
  on "accounts"."rehab_plans"
  as permissive
  for delete
  to authenticated
using (((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles pt
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pt.id = rehab_plans.pt_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id))))));



  create policy "rehab_plans_insert_by_pt"
  on "accounts"."rehab_plans"
  as permissive
  for insert
  to authenticated
with check ((EXISTS ( SELECT 1
   FROM ((accounts.pt_patient_map m
     JOIN accounts.pt_profiles pt ON ((pt.id = m.pt_profile_id)))
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((m.patient_profile_id = rehab_plans.patient_profile_id) AND (m.pt_profile_id = rehab_plans.pt_profile_id) AND (p.user_id = auth.uid())))));



  create policy "rehab_plans_insert_owner"
  on "accounts"."rehab_plans"
  as permissive
  for insert
  to authenticated
with check (((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles pt
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pt.id = rehab_plans.pt_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id))))));



  create policy "rehab_plans_select_owner"
  on "accounts"."rehab_plans"
  as permissive
  for select
  to authenticated
using (((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles pt
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pt.id = rehab_plans.pt_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id))))));



  create policy "rehab_plans_update_owner"
  on "accounts"."rehab_plans"
  as permissive
  for update
  to authenticated
using (((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles pt
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pt.id = rehab_plans.pt_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id))))))
with check (((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles pt
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pt.id = rehab_plans.pt_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id))))));



  create policy "pt_patient_map_delete_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for delete
  to authenticated
using ((accounts.is_pt_owned(pt_profile_id) OR accounts.is_patient_owned(patient_profile_id)));



  create policy "pt_patient_map_insert_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for insert
  to authenticated
with check ((accounts.is_pt_owned(pt_profile_id) OR accounts.is_patient_owned(patient_profile_id)));



  create policy "pt_patient_map_select_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for select
  to authenticated
using ((accounts.is_pt_owned(pt_profile_id) OR accounts.is_patient_owned(patient_profile_id)));



  create policy "pt_patient_map_update_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for update
  to authenticated
using ((accounts.is_pt_owned(pt_profile_id) OR accounts.is_patient_owned(patient_profile_id)))
with check ((accounts.is_pt_owned(pt_profile_id) OR accounts.is_patient_owned(patient_profile_id)));



