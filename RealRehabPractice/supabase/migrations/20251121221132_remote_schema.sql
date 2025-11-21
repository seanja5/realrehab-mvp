drop policy "patient_profiles_select_owner" on "accounts"."patient_profiles";

drop policy "pt_patient_map_delete_owner" on "accounts"."pt_patient_map";

drop policy "pt_patient_map_insert_owner" on "accounts"."pt_patient_map";

drop policy "pt_patient_map_select_owner" on "accounts"."pt_patient_map";

drop policy "pt_patient_map_update_owner" on "accounts"."pt_patient_map";

drop policy "rehab_plans_select_owner" on "accounts"."rehab_plans";

drop policy "device_assignments_access" on "telemetry"."device_assignments";

alter table "accounts"."patient_profiles" add column "access_code" text;

CREATE UNIQUE INDEX idx_patient_profiles_access_code ON accounts.patient_profiles USING btree (access_code) WHERE (access_code IS NOT NULL);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION accounts.delete_pt_patient_mapping(p_pt_profile_id uuid, p_patient_profile_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
DECLARE
    v_current_user_id UUID;
    v_pt_profile_id UUID;
BEGIN
    -- Get current user
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;
    
    -- Verify the PT profile belongs to the current user
    SELECT ptp.id INTO v_pt_profile_id
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = p_pt_profile_id
      AND p.user_id = v_current_user_id;
    
    IF v_pt_profile_id IS NULL THEN
        RAISE EXCEPTION 'PT profile does not belong to current user';
    END IF;
    
    -- Delete the mapping
    DELETE FROM accounts.pt_patient_map
    WHERE pt_profile_id = p_pt_profile_id
      AND patient_profile_id = p_patient_profile_id;
    
    -- Also clear access_code in patient_profiles (optional cleanup)
    UPDATE accounts.patient_profiles
    SET access_code = NULL
    WHERE id = p_patient_profile_id;
    
END;
$function$
;

CREATE OR REPLACE FUNCTION accounts.generate_unique_access_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_code text;
  v_exists boolean;
  v_attempts int := 0;
  v_max_attempts int := 100;
BEGIN
  LOOP
    -- Generate random 8-digit code (padded with zeros)
    v_code := LPAD(FLOOR(RANDOM() * 100000000)::text, 8, '0');
    
    -- Check if code already exists
    SELECT EXISTS(
      SELECT 1 
      FROM accounts.patient_profiles 
      WHERE access_code = v_code
    ) INTO v_exists;
    
    -- If code doesn't exist, return it
    EXIT WHEN NOT v_exists;
    
    -- Safety check to prevent infinite loop
    v_attempts := v_attempts + 1;
    IF v_attempts >= v_max_attempts THEN
      RAISE EXCEPTION 'Failed to generate unique access code after % attempts', v_max_attempts;
    END IF;
  END LOOP;
  
  RETURN v_code;
END;
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_patient_profile_owned(patient_profile_id_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pat
    WHERE pat.id = patient_profile_id_uuid
      AND pat.profile_id IN (
        SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
      )
  );
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_pt_mapped_to_patient_profile(profile_id_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.patient_profiles pat ON ptm.patient_profile_id = pat.id
    INNER JOIN accounts.pt_profiles pt ON ptm.pt_profile_id = pt.id
    INNER JOIN accounts.profiles pt_profile ON pt.profile_id = pt_profile.id
    WHERE pat.profile_id = profile_id_uuid
      AND pt_profile.user_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION public.add_patient_with_mapping(p_first_name text, p_last_name text, p_date_of_birth text, p_gender text, p_pt_profile_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
DECLARE
  v_patient_id uuid;
  v_current_user_id uuid;
BEGIN
  -- Get current user ID
  v_current_user_id := auth.uid();
  
  -- Verify that the PT profile belongs to the current user
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = p_pt_profile_id
      AND p.user_id = v_current_user_id
  ) THEN
    RAISE EXCEPTION 'PT profile does not belong to current user';
  END IF;
  
  -- Create patient profile placeholder
  INSERT INTO accounts.patient_profiles (
    profile_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    access_code
  ) VALUES (
    NULL,  -- Explicitly NULL (placeholder)
    p_first_name,
    p_last_name,
    p_date_of_birth::date,  -- Cast text to date (ISO8601 format YYYY-MM-DD)
    p_gender::accounts.gender,  -- Cast text to accounts.gender enum
    accounts.generate_unique_access_code()  -- Generate unique 8-digit access code
  ) RETURNING id INTO v_patient_id;
  
  -- Create pt_patient_map entry
  INSERT INTO accounts.pt_patient_map (
    patient_profile_id,
    pt_profile_id
  ) VALUES (
    v_patient_id,
    p_pt_profile_id
  )
  ON CONFLICT (patient_profile_id) DO UPDATE
  SET pt_profile_id = p_pt_profile_id;
  
  RETURN v_patient_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_or_create_device_assignment(p_bluetooth_identifier text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'telemetry', 'accounts', 'public'
AS $function$
DECLARE
  v_device_id uuid;
  v_device_assignment_id uuid;
  v_patient_profile_id uuid;
  v_pt_profile_id uuid;
  v_current_user_id uuid;
BEGIN
  -- Get current user ID (before switching role)
  v_current_user_id := auth.uid();
  
  -- Get patient profile ID for current user
  SELECT pp.id INTO v_patient_profile_id
  FROM accounts.patient_profiles pp
  INNER JOIN accounts.profiles p ON pp.profile_id = p.id
  WHERE p.user_id = v_current_user_id
  LIMIT 1;
  
  IF v_patient_profile_id IS NULL THEN
    RAISE EXCEPTION 'No patient profile found for current user';
  END IF;
  
  -- Get or create device (RLS bypassed by SECURITY DEFINER)
  SELECT id INTO v_device_id
  FROM telemetry.devices
  WHERE hardware_serial = p_bluetooth_identifier
  LIMIT 1;
  
  IF v_device_id IS NULL THEN
    -- Create new device (RLS bypassed by SECURITY DEFINER)
    INSERT INTO telemetry.devices (
      hardware_serial,
      status
    ) VALUES (
      p_bluetooth_identifier,
      'unpaired'::telemetry.device_status
    ) RETURNING id INTO v_device_id;
  END IF;
  
  -- Get PT profile ID if patient is linked to a PT
  SELECT ptm.pt_profile_id INTO v_pt_profile_id
  FROM accounts.pt_patient_map ptm
  WHERE ptm.patient_profile_id = v_patient_profile_id
  LIMIT 1;
  
  -- Get or create device assignment (RLS bypassed)
  SELECT id INTO v_device_assignment_id
  FROM telemetry.device_assignments
  WHERE device_id = v_device_id
    AND patient_profile_id = v_patient_profile_id
    AND is_active = true
  LIMIT 1;
  
  IF v_device_assignment_id IS NULL THEN
    -- Create new device assignment (RLS bypassed by SECURITY DEFINER)
    INSERT INTO telemetry.device_assignments (
      device_id,
      patient_profile_id,
      pt_profile_id,
      is_active
    ) VALUES (
      v_device_id,
      v_patient_profile_id,
      v_pt_profile_id,
      true
    ) RETURNING id INTO v_device_assignment_id;
  END IF;
  
  RETURN v_device_assignment_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_pt_profile_id_by_access_code(access_code_param text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
DECLARE
  placeholder_id uuid;
  pt_profile_id_result uuid;
BEGIN
  -- Step 1: Find the placeholder patient profile by access code
  -- Only look for placeholders (profile_id IS NULL) that haven't been linked yet
  SELECT id INTO placeholder_id
  FROM accounts.patient_profiles
  WHERE access_code = access_code_param
    AND profile_id IS NULL
  LIMIT 1;
  
  -- If no placeholder found, return NULL
  IF placeholder_id IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Step 2: Get the PT profile ID from pt_patient_map
  SELECT pt_profile_id INTO pt_profile_id_result
  FROM accounts.pt_patient_map
  WHERE patient_profile_id = placeholder_id
  LIMIT 1;
  
  -- Return the PT profile ID (or NULL if not found)
  RETURN pt_profile_id_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.insert_patient_profile_placeholder(p_first_name text, p_last_name text, p_date_of_birth text, p_gender text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
DECLARE
  v_patient_id uuid;
BEGIN
  INSERT INTO accounts.patient_profiles (
    profile_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    access_code
  ) VALUES (
    NULL,  -- Explicitly NULL
    p_first_name,
    p_last_name,
    p_date_of_birth::date,  -- Cast text to date (ISO8601 format YYYY-MM-DD)
    p_gender::accounts.gender,  -- Cast text to accounts.gender enum
    accounts.generate_unique_access_code()  -- Generate unique 8-digit access code
  ) RETURNING id INTO v_patient_id;
  
  RETURN v_patient_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.link_patient_to_pt(patient_profile_id_param uuid, pt_profile_id_param uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
BEGIN
  -- Verify that the patient_profile_id belongs to the current user
  -- This ensures patients can only link their own profile
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.patient_profiles pat
    WHERE pat.id = patient_profile_id_param
      AND pat.profile_id IN (
        SELECT id FROM accounts.profiles WHERE user_id = auth.uid()
      )
  ) THEN
    RAISE EXCEPTION 'Patient profile does not belong to current user';
  END IF;
  
  -- Verify that the PT profile exists
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles
    WHERE id = pt_profile_id_param
  ) THEN
    RAISE EXCEPTION 'PT profile not found';
  END IF;
  
  -- Insert or update the mapping (upsert)
  INSERT INTO accounts.pt_patient_map (patient_profile_id, pt_profile_id)
  VALUES (patient_profile_id_param, pt_profile_id_param)
  ON CONFLICT (patient_profile_id)
  DO UPDATE SET pt_profile_id = pt_profile_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.link_patient_via_access_code(access_code_param text, patient_profile_id_param uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
DECLARE
  placeholder_id uuid;
  pt_profile_id_result uuid;
  current_profile_id uuid;
  patient_first_name text;
  patient_last_name text;
  patient_phone text;
  patient_dob text;
  patient_gender text;
  patient_surgery_date text;
  patient_last_pt_visit text;
BEGIN
  -- Step 1: Verify that the patient_profile_id belongs to the current user
  SELECT profile_id INTO current_profile_id
  FROM accounts.patient_profiles
  WHERE id = patient_profile_id_param;
  
  IF current_profile_id IS NULL THEN
    RAISE EXCEPTION 'Patient profile not found';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1
    FROM accounts.profiles
    WHERE id = current_profile_id
      AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Patient profile does not belong to current user';
  END IF;
  
  -- Step 2: Find placeholder by access code
  SELECT id INTO placeholder_id
  FROM accounts.patient_profiles
  WHERE access_code = access_code_param
    AND profile_id IS NULL
  LIMIT 1;
  
  IF placeholder_id IS NULL THEN
    RAISE EXCEPTION 'Invalid access code';
  END IF;
  
  -- Step 3: Get PT profile ID from the placeholder's mapping
  SELECT pt_profile_id INTO pt_profile_id_result
  FROM accounts.pt_patient_map
  WHERE patient_profile_id = placeholder_id
  LIMIT 1;
  
  IF pt_profile_id_result IS NULL THEN
    RAISE EXCEPTION 'No Physical Therapist found for this access code';
  END IF;
  
  -- Step 4: Get patient's data from their existing profile
  -- Cast date_of_birth, gender, surgery_date, and last_pt_visit to text to ensure type consistency
  SELECT 
    first_name, 
    last_name, 
    phone, 
    date_of_birth::text, 
    gender::text,
    surgery_date::text,
    last_pt_visit::text
  INTO 
    patient_first_name, 
    patient_last_name, 
    patient_phone, 
    patient_dob, 
    patient_gender,
    patient_surgery_date,
    patient_last_pt_visit
  FROM accounts.patient_profiles
  WHERE id = patient_profile_id_param;
  
  -- Step 5: Delete the original patient_profiles row FIRST (before updating placeholder)
  -- This prevents unique constraint violation on profile_id
  -- Only delete if it's different from the placeholder
  IF patient_profile_id_param != placeholder_id THEN
    DELETE FROM accounts.patient_profiles
    WHERE id = patient_profile_id_param
      AND profile_id = current_profile_id;
  END IF;
  
  -- Step 6: Update the placeholder with patient's profile_id and data
  -- Use CASE to handle date_of_birth, gender, surgery_date, and last_pt_visit properly (cast to correct types)
  UPDATE accounts.patient_profiles
  SET 
    profile_id = current_profile_id,
    first_name = COALESCE(patient_first_name, first_name),
    last_name = COALESCE(patient_last_name, last_name),
    phone = COALESCE(patient_phone, phone),
    date_of_birth = CASE 
      WHEN patient_dob IS NOT NULL THEN patient_dob::date
      ELSE date_of_birth
    END,
    gender = CASE 
      WHEN patient_gender IS NOT NULL THEN patient_gender::accounts.gender
      ELSE gender
    END,
    surgery_date = CASE 
      WHEN patient_surgery_date IS NOT NULL THEN patient_surgery_date::date
      ELSE surgery_date
    END,
    last_pt_visit = CASE 
      WHEN patient_last_pt_visit IS NOT NULL THEN patient_last_pt_visit::date
      ELSE last_pt_visit
    END
  WHERE id = placeholder_id;
  
  -- Step 7: Update pt_patient_map to point to placeholder (if it doesn't already)
  -- This ensures the mapping uses the placeholder ID (which now has profile_id set)
  INSERT INTO accounts.pt_patient_map (patient_profile_id, pt_profile_id)
  VALUES (placeholder_id, pt_profile_id_result)
  ON CONFLICT (patient_profile_id)
  DO UPDATE SET pt_profile_id = pt_profile_id_result;
  
  -- Step 8: Delete any duplicate mapping that might point to the real patient_profile_id
  -- (in case one was created before this function was called)
  DELETE FROM accounts.pt_patient_map
  WHERE patient_profile_id = patient_profile_id_param
    AND patient_profile_id != placeholder_id;
END;
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
    FROM accounts.pt_profiles ptp
    INNER JOIN accounts.profiles p ON ptp.profile_id = p.id
    WHERE ptp.id = pt_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$function$
;


  create policy "profiles_select_owner_or_pt_mapped"
  on "accounts"."profiles"
  as permissive
  for select
  to authenticated
using (((user_id = auth.uid()) OR accounts.is_pt_mapped_to_patient_profile(id)));



  create policy "patient_profiles_select_owner"
  on "accounts"."patient_profiles"
  as permissive
  for select
  to authenticated
using (((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))) OR (profile_id IS NULL) OR accounts.is_patient_mapped_to_current_pt(id)));



  create policy "pt_patient_map_delete_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for delete
  to authenticated
using ((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles ptp
     JOIN accounts.profiles p ON ((ptp.profile_id = p.id)))
  WHERE ((ptp.id = pt_patient_map.pt_profile_id) AND (p.user_id = auth.uid())))));



  create policy "pt_patient_map_insert_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for insert
  to authenticated
with check (accounts.is_pt_owned(pt_profile_id));



  create policy "pt_patient_map_select_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for select
  to authenticated
using ((accounts.is_pt_owned(pt_profile_id) OR accounts.is_patient_profile_owned(patient_profile_id)));



  create policy "pt_patient_map_update_owner"
  on "accounts"."pt_patient_map"
  as permissive
  for update
  to authenticated
using (accounts.is_pt_owned(pt_profile_id))
with check (accounts.is_pt_owned(pt_profile_id));



  create policy "rehab_plans_select_owner"
  on "accounts"."rehab_plans"
  as permissive
  for select
  to authenticated
using ((((EXISTS ( SELECT 1
   FROM (accounts.pt_profiles pt
     JOIN accounts.profiles p ON ((p.id = pt.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pt.id = rehab_plans.pt_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id))))) OR ((EXISTS ( SELECT 1
   FROM (accounts.patient_profiles pat
     JOIN accounts.profiles p ON ((p.id = pat.profile_id)))
  WHERE ((p.user_id = auth.uid()) AND (pat.id = rehab_plans.patient_profile_id)))) AND (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map m
  WHERE ((m.pt_profile_id = rehab_plans.pt_profile_id) AND (m.patient_profile_id = rehab_plans.patient_profile_id)))))));



  create policy "device_assignments_access"
  on "telemetry"."device_assignments"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (CURRENT_USER = 'postgres'::name) OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = pt_profile_id)) OR (accounts.is_patient() AND (accounts.current_patient_profile_id() = patient_profile_id))))
with check ((accounts.is_admin() OR (CURRENT_USER = 'postgres'::name) OR (accounts.is_pt() AND ((accounts.current_pt_profile_id() = pt_profile_id) OR (pt_profile_id IS NULL))) OR (accounts.is_patient() AND (accounts.current_patient_profile_id() = patient_profile_id) AND ((pt_profile_id IS NULL) OR (EXISTS ( SELECT 1
   FROM accounts.pt_patient_map ptm
  WHERE ((ptm.patient_profile_id = accounts.current_patient_profile_id()) AND (ptm.pt_profile_id = device_assignments.pt_profile_id))))))));



