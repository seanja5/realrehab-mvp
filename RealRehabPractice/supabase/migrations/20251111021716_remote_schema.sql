


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "accounts";


ALTER SCHEMA "accounts" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "content";


ALTER SCHEMA "content" OWNER TO "postgres";




ALTER SCHEMA "public" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "rehab";


ALTER SCHEMA "rehab" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "telemetry";


ALTER SCHEMA "telemetry" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "citext" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "accounts"."assignment_status" AS ENUM (
    'pending',
    'active',
    'suspended',
    'archived'
);


ALTER TYPE "accounts"."assignment_status" OWNER TO "postgres";


CREATE TYPE "accounts"."gender" AS ENUM (
    'female',
    'male',
    'non_binary',
    'prefer_not_to_say',
    'other'
);


ALTER TYPE "accounts"."gender" OWNER TO "postgres";


CREATE TYPE "accounts"."user_role" AS ENUM (
    'patient',
    'pt',
    'admin'
);


ALTER TYPE "accounts"."user_role" OWNER TO "postgres";


CREATE TYPE "content"."asset_purpose" AS ENUM (
    'session_upload',
    'lesson_reference',
    'plan_resource'
);


ALTER TYPE "content"."asset_purpose" OWNER TO "postgres";


CREATE TYPE "content"."asset_status" AS ENUM (
    'pending',
    'available',
    'processing',
    'failed'
);


ALTER TYPE "content"."asset_status" OWNER TO "postgres";


CREATE TYPE "rehab"."exercise_difficulty" AS ENUM (
    'beginner',
    'intermediate',
    'advanced'
);


ALTER TYPE "rehab"."exercise_difficulty" OWNER TO "postgres";


CREATE TYPE "rehab"."lesson_phase" AS ENUM (
    'phase_1',
    'phase_2',
    'phase_3',
    'phase_4'
);


ALTER TYPE "rehab"."lesson_phase" OWNER TO "postgres";


CREATE TYPE "rehab"."plan_status" AS ENUM (
    'draft',
    'active',
    'suspended',
    'completed',
    'archived'
);


ALTER TYPE "rehab"."plan_status" OWNER TO "postgres";


CREATE TYPE "rehab"."session_status" AS ENUM (
    'scheduled',
    'in_progress',
    'completed',
    'aborted'
);


ALTER TYPE "rehab"."session_status" OWNER TO "postgres";


CREATE TYPE "telemetry"."calibration_stage" AS ENUM (
    'starting_position',
    'maximum_position',
    'full_range'
);


ALTER TYPE "telemetry"."calibration_stage" OWNER TO "postgres";


CREATE TYPE "telemetry"."device_status" AS ENUM (
    'unpaired',
    'paired',
    'maintenance',
    'retired'
);


ALTER TYPE "telemetry"."device_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."current_patient_profile_id"() RETURNS "uuid"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select patient_profiles.id
  from accounts.patient_profiles
  join accounts.profiles on profiles.id = patient_profiles.profile_id
  where profiles.user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "accounts"."current_patient_profile_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."current_profile_id"() RETURNS "uuid"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select id
  from accounts.profiles
  where user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "accounts"."current_profile_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."current_pt_profile_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  SELECT pt.id
  FROM accounts.pt_profiles pt
  JOIN accounts.profiles p ON p.id = pt.profile_id
  WHERE p.user_id = auth.uid()
  LIMIT 1;
$$;


ALTER FUNCTION "accounts"."current_pt_profile_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."current_role"() RETURNS "accounts"."user_role"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select role
  from accounts.profiles
  where user_id = auth.uid()
  limit 1;
$$;


ALTER FUNCTION "accounts"."current_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_admin"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select coalesce(accounts.current_role() = 'admin', false);
$$;


ALTER FUNCTION "accounts"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_current_user_pt"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.profiles
    WHERE user_id = auth.uid()
    AND role = 'pt'
  );
$$;


ALTER FUNCTION "accounts"."is_current_user_pt"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_patient"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select coalesce(accounts.current_role() = 'patient', false);
$$;


ALTER FUNCTION "accounts"."is_patient"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_patient_associated_with"("pt_profile" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select exists (
    select 1
    from accounts.pt_patient_map map
    where map.patient_profile_id = accounts.current_patient_profile_id()
      and map.pt_profile_id = pt_profile
      and map.status = 'active'
  );
$$;


ALTER FUNCTION "accounts"."is_patient_associated_with"("pt_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_patient_mapped_to_current_pt"("patient_profile_id_uuid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;


ALTER FUNCTION "accounts"."is_patient_mapped_to_current_pt"("patient_profile_id_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_pt"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM accounts.profiles p
    WHERE p.user_id = auth.uid() AND p.role = 'pt'
  );
$$;


ALTER FUNCTION "accounts"."is_pt"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_pt_assigned_to"("patient_profile" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  select exists (
    select 1
    from accounts.pt_patient_map map
    where map.patient_profile_id = patient_profile
      and map.pt_profile_id = accounts.current_pt_profile_id()
      and map.status = 'active'
  );
$$;


ALTER FUNCTION "accounts"."is_pt_assigned_to"("patient_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_pt_owned"("pt_profile_id_uuid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  -- Direct join to profiles to check ownership
  -- This bypasses RLS because function runs with DEFINER privileges
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_profiles pp
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE pp.id = pt_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$$;


ALTER FUNCTION "accounts"."is_pt_owned"("pt_profile_id_uuid" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."is_pt_owner_of"("patient_profile" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map m
    JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
    JOIN accounts.profiles p     ON p.id  = pt.profile_id
    WHERE m.patient_profile_id = patient_profile
      AND p.user_id = auth.uid()
  );
$$;


ALTER FUNCTION "accounts"."is_pt_owner_of"("patient_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "accounts"."link_patient_to_current_pt"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'accounts', 'public'
    AS $$
DECLARE
  v_pt uuid;
BEGIN
  IF accounts.is_pt() THEN
    v_pt := accounts.current_pt_profile_id();
    IF v_pt IS NOT NULL THEN
      -- Upsert mapping; primary key on patient_profile_id avoids dupes
      INSERT INTO accounts.pt_patient_map (patient_profile_id, pt_profile_id)
      VALUES (NEW.id, v_pt)
      ON CONFLICT (patient_profile_id) DO UPDATE
      SET pt_profile_id = EXCLUDED.pt_profile_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "accounts"."link_patient_to_current_pt"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."touch_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "accounts"."admin_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "title" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "accounts"."admin_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "accounts"."patient_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "date_of_birth" "date",
    "gender" "accounts"."gender",
    "surgery_date" "date",
    "last_pt_visit" "date",
    "allow_notifications" boolean DEFAULT true NOT NULL,
    "allow_camera" boolean DEFAULT true NOT NULL,
    "intake_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone" "text",
    "first_name" "text",
    "last_name" "text"
);


ALTER TABLE "accounts"."patient_profiles" OWNER TO "postgres";


COMMENT ON COLUMN "accounts"."patient_profiles"."profile_id" IS 'NULL for PT-added placeholders. Set to accounts.profiles.id once the patient claims the record.';



CREATE TABLE IF NOT EXISTS "accounts"."profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "accounts"."user_role" NOT NULL,
    "email" "public"."citext" NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "phone" "text",
    "timezone" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "accounts"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "accounts"."pt_patient_map" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "patient_profile_id" "uuid" NOT NULL,
    "pt_profile_id" "uuid" NOT NULL,
    "status" "accounts"."assignment_status" DEFAULT 'pending'::"accounts"."assignment_status" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accepted_at" timestamp with time zone,
    "archived_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "accounts"."pt_patient_map" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "accounts"."pt_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "profile_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" "text",
    "first_name" "text",
    "last_name" "text",
    "phone" "text",
    "license_number" "text",
    "npi_number" "text",
    "practice_name" "text",
    "practice_address" "text",
    "specialization" "text"
);


ALTER TABLE "accounts"."pt_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "accounts"."pt_profiles_backup_20251109" (
    "id" "uuid",
    "profile_id" "uuid",
    "practice_name" "text",
    "license_number" "text",
    "npi_number" "text",
    "contact_email" "public"."citext",
    "contact_phone" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "email" "text",
    "first_name" "text",
    "last_name" "text",
    "phone" "text"
);


ALTER TABLE "accounts"."pt_profiles_backup_20251109" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "accounts"."rehab_plans" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "pt_profile_id" "uuid" NOT NULL,
    "patient_profile_id" "uuid" NOT NULL,
    "category" "text" NOT NULL,
    "injury" "text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "accounts"."rehab_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "content"."assets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "uploader_profile_id" "uuid" NOT NULL,
    "status" "content"."asset_status" DEFAULT 'pending'::"content"."asset_status" NOT NULL,
    "purpose" "content"."asset_purpose" DEFAULT 'session_upload'::"content"."asset_purpose" NOT NULL,
    "storage_path" "text" NOT NULL,
    "file_name" "text",
    "content_type" "text",
    "duration_seconds" numeric(8,2),
    "file_size_bytes" bigint,
    "linked_session_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "content"."assets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "content"."lesson_assets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_lesson_id" "uuid" NOT NULL,
    "asset_id" "uuid" NOT NULL,
    "is_primary" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "content"."lesson_assets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."exercises" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "description" "text",
    "body_region" "text",
    "difficulty" "rehab"."exercise_difficulty" DEFAULT 'beginner'::"rehab"."exercise_difficulty" NOT NULL,
    "default_reps" integer,
    "default_rest_seconds" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."exercises" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."lesson_progress" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_assignment_id" "uuid" NOT NULL,
    "plan_lesson_id" "uuid" NOT NULL,
    "unlocked_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "last_session_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."lesson_progress" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."plan_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "patient_profile_id" "uuid" NOT NULL,
    "pt_profile_id" "uuid" NOT NULL,
    "started_on" "date",
    "completed_on" "date",
    "allow_reminders" boolean DEFAULT true NOT NULL,
    "allow_camera" boolean DEFAULT true NOT NULL,
    "timezone" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."plan_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."plan_lessons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_id" "uuid" NOT NULL,
    "exercise_id" "uuid",
    "phase" "rehab"."lesson_phase" DEFAULT 'phase_1'::"rehab"."lesson_phase" NOT NULL,
    "title" "text",
    "icon_name" "text",
    "is_locked" boolean DEFAULT false NOT NULL,
    "reps" integer,
    "rest_seconds" integer,
    "sequence_position" integer NOT NULL,
    "video_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."plan_lessons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."plan_schedule_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_assignment_id" "uuid" NOT NULL,
    "day_of_week" smallint NOT NULL,
    "slot_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "plan_schedule_slots_day_of_week_check" CHECK ((("day_of_week" >= 0) AND ("day_of_week" <= 6)))
);


ALTER TABLE "rehab"."plan_schedule_slots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "injury_focus" "text" DEFAULT 'ACL Tear Recovery'::"text" NOT NULL,
    "status" "rehab"."plan_status" DEFAULT 'draft'::"rehab"."plan_status" NOT NULL,
    "created_by_pt_profile_id" "uuid" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."session_metrics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "total_reps" integer,
    "accuracy_percent" numeric(5,2),
    "range_of_motion_deg" numeric(6,2),
    "session_duration_seconds" integer,
    "average_flex_value" numeric(8,4),
    "peak_flex_value" numeric(8,4),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."session_metrics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "rehab"."sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "plan_assignment_id" "uuid" NOT NULL,
    "plan_lesson_id" "uuid" NOT NULL,
    "status" "rehab"."session_status" DEFAULT 'scheduled'::"rehab"."session_status" NOT NULL,
    "scheduled_for" timestamp with time zone,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "expected_reps" integer,
    "expected_rest_seconds" integer,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "rehab"."sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "telemetry"."calibrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_assignment_id" "uuid" NOT NULL,
    "stage" "telemetry"."calibration_stage" NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "flex_value" numeric(8,4),
    "knee_angle_deg" numeric(6,2),
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "telemetry"."calibrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "telemetry"."device_assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "uuid" NOT NULL,
    "patient_profile_id" "uuid" NOT NULL,
    "pt_profile_id" "uuid",
    "paired_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "unpaired_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "telemetry"."device_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "telemetry"."devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "hardware_serial" "text" NOT NULL,
    "firmware_version" "text",
    "status" "telemetry"."device_status" DEFAULT 'unpaired'::"telemetry"."device_status" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "telemetry"."devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "telemetry"."session_samples" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "device_assignment_id" "uuid",
    "recorded_at" timestamp with time zone NOT NULL,
    "flex_value" numeric(10,5),
    "knee_angle_deg" numeric(6,2),
    "quat_w" double precision,
    "quat_x" double precision,
    "quat_y" double precision,
    "quat_z" double precision,
    "accel_x" double precision,
    "accel_y" double precision,
    "accel_z" double precision,
    "gyro_x" double precision,
    "gyro_y" double precision,
    "gyro_z" double precision,
    "temperature_c" double precision,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "telemetry"."session_samples" OWNER TO "postgres";


ALTER TABLE ONLY "accounts"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "accounts"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "accounts"."patient_profiles"
    ADD CONSTRAINT "patient_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "accounts"."patient_profiles"
    ADD CONSTRAINT "patient_profiles_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "accounts"."patient_profiles"
    ADD CONSTRAINT "patient_profiles_profile_id_unique" UNIQUE ("profile_id");



ALTER TABLE ONLY "accounts"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "accounts"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "accounts"."profiles"
    ADD CONSTRAINT "profiles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "accounts"."pt_patient_map"
    ADD CONSTRAINT "pt_patient_map_patient_profile_id_pt_profile_id_key" UNIQUE ("patient_profile_id", "pt_profile_id");



ALTER TABLE ONLY "accounts"."pt_patient_map"
    ADD CONSTRAINT "pt_patient_map_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "accounts"."pt_profiles"
    ADD CONSTRAINT "pt_profiles_email_unique" UNIQUE ("email");



ALTER TABLE ONLY "accounts"."pt_profiles"
    ADD CONSTRAINT "pt_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "accounts"."pt_profiles"
    ADD CONSTRAINT "pt_profiles_profile_id_key" UNIQUE ("profile_id");



ALTER TABLE ONLY "accounts"."pt_profiles"
    ADD CONSTRAINT "pt_profiles_profile_id_unique" UNIQUE ("profile_id");



ALTER TABLE ONLY "accounts"."rehab_plans"
    ADD CONSTRAINT "rehab_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "content"."assets"
    ADD CONSTRAINT "assets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "content"."assets"
    ADD CONSTRAINT "assets_storage_path_key" UNIQUE ("storage_path");



ALTER TABLE ONLY "content"."lesson_assets"
    ADD CONSTRAINT "lesson_assets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "content"."lesson_assets"
    ADD CONSTRAINT "lesson_assets_plan_lesson_id_asset_id_key" UNIQUE ("plan_lesson_id", "asset_id");



ALTER TABLE ONLY "rehab"."exercises"
    ADD CONSTRAINT "exercises_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."exercises"
    ADD CONSTRAINT "exercises_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "rehab"."lesson_progress"
    ADD CONSTRAINT "lesson_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."lesson_progress"
    ADD CONSTRAINT "lesson_progress_plan_assignment_id_plan_lesson_id_key" UNIQUE ("plan_assignment_id", "plan_lesson_id");



ALTER TABLE ONLY "rehab"."plan_assignments"
    ADD CONSTRAINT "plan_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."plan_assignments"
    ADD CONSTRAINT "plan_assignments_plan_id_patient_profile_id_key" UNIQUE ("plan_id", "patient_profile_id");



ALTER TABLE ONLY "rehab"."plan_lessons"
    ADD CONSTRAINT "plan_lessons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."plan_lessons"
    ADD CONSTRAINT "plan_lessons_plan_id_sequence_position_key" UNIQUE ("plan_id", "sequence_position");



ALTER TABLE ONLY "rehab"."plan_schedule_slots"
    ADD CONSTRAINT "plan_schedule_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."session_metrics"
    ADD CONSTRAINT "session_metrics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "rehab"."session_metrics"
    ADD CONSTRAINT "session_metrics_session_id_key" UNIQUE ("session_id");



ALTER TABLE ONLY "rehab"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "telemetry"."calibrations"
    ADD CONSTRAINT "calibrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "telemetry"."device_assignments"
    ADD CONSTRAINT "device_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "telemetry"."devices"
    ADD CONSTRAINT "devices_hardware_serial_key" UNIQUE ("hardware_serial");



ALTER TABLE ONLY "telemetry"."devices"
    ADD CONSTRAINT "devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "telemetry"."session_samples"
    ADD CONSTRAINT "session_samples_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_profiles_role" ON "accounts"."profiles" USING "btree" ("role");



CREATE INDEX "idx_pt_patient_map_patient" ON "accounts"."pt_patient_map" USING "btree" ("patient_profile_id");



CREATE UNIQUE INDEX "idx_pt_patient_map_patient_profile_id_unique" ON "accounts"."pt_patient_map" USING "btree" ("patient_profile_id");



CREATE INDEX "idx_pt_patient_map_pt" ON "accounts"."pt_patient_map" USING "btree" ("pt_profile_id");



CREATE INDEX "idx_pt_patient_map_status" ON "accounts"."pt_patient_map" USING "btree" ("status");



CREATE UNIQUE INDEX "uniq_active_plan_per_patient" ON "accounts"."rehab_plans" USING "btree" ("patient_profile_id") WHERE ("status" = 'active'::"text");



CREATE INDEX "idx_assets_session" ON "content"."assets" USING "btree" ("linked_session_id");



CREATE INDEX "idx_assets_uploader" ON "content"."assets" USING "btree" ("uploader_profile_id");



CREATE INDEX "idx_lesson_assets_lesson" ON "content"."lesson_assets" USING "btree" ("plan_lesson_id");



CREATE INDEX "idx_plan_assignments_patient" ON "rehab"."plan_assignments" USING "btree" ("patient_profile_id");



CREATE INDEX "idx_plan_assignments_pt" ON "rehab"."plan_assignments" USING "btree" ("pt_profile_id");



CREATE INDEX "idx_plan_lessons_exercise" ON "rehab"."plan_lessons" USING "btree" ("exercise_id");



CREATE INDEX "idx_plan_lessons_plan" ON "rehab"."plan_lessons" USING "btree" ("plan_id");



CREATE INDEX "idx_plan_schedule_slots_assignment" ON "rehab"."plan_schedule_slots" USING "btree" ("plan_assignment_id");



CREATE INDEX "idx_plan_schedule_slots_day" ON "rehab"."plan_schedule_slots" USING "btree" ("day_of_week");



CREATE INDEX "idx_plans_created_by_pt" ON "rehab"."plans" USING "btree" ("created_by_pt_profile_id");



CREATE INDEX "idx_plans_status" ON "rehab"."plans" USING "btree" ("status");



CREATE INDEX "idx_sessions_assignment" ON "rehab"."sessions" USING "btree" ("plan_assignment_id");



CREATE INDEX "idx_sessions_lesson" ON "rehab"."sessions" USING "btree" ("plan_lesson_id");



CREATE INDEX "idx_sessions_status" ON "rehab"."sessions" USING "btree" ("status");



CREATE INDEX "idx_calibrations_assignment" ON "telemetry"."calibrations" USING "btree" ("device_assignment_id");



CREATE INDEX "idx_calibrations_stage" ON "telemetry"."calibrations" USING "btree" ("stage");



CREATE INDEX "idx_device_assignments_device" ON "telemetry"."device_assignments" USING "btree" ("device_id");



CREATE INDEX "idx_device_assignments_patient" ON "telemetry"."device_assignments" USING "btree" ("patient_profile_id");



CREATE INDEX "idx_session_samples_recorded_at" ON "telemetry"."session_samples" USING "btree" ("session_id", "recorded_at");



CREATE INDEX "idx_session_samples_session" ON "telemetry"."session_samples" USING "btree" ("session_id");



CREATE UNIQUE INDEX "uniq_device_active_assignment" ON "telemetry"."device_assignments" USING "btree" ("device_id") WHERE "is_active";



CREATE OR REPLACE TRIGGER "trg_admin_profiles_updated_at" BEFORE UPDATE ON "accounts"."admin_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_link_patient_to_pt" AFTER INSERT ON "accounts"."patient_profiles" FOR EACH ROW EXECUTE FUNCTION "accounts"."link_patient_to_current_pt"();



CREATE OR REPLACE TRIGGER "trg_patient_profiles_updated_at" BEFORE UPDATE ON "accounts"."patient_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_profiles_updated_at" BEFORE UPDATE ON "accounts"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_pt_patient_map_updated_at" BEFORE UPDATE ON "accounts"."pt_patient_map" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_pt_profiles_updated_at" BEFORE UPDATE ON "accounts"."pt_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_assets_updated_at" BEFORE UPDATE ON "content"."assets" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_exercises_updated_at" BEFORE UPDATE ON "rehab"."exercises" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_lesson_progress_updated_at" BEFORE UPDATE ON "rehab"."lesson_progress" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_plan_assignments_updated_at" BEFORE UPDATE ON "rehab"."plan_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_plan_lessons_updated_at" BEFORE UPDATE ON "rehab"."plan_lessons" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_plans_updated_at" BEFORE UPDATE ON "rehab"."plans" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_session_metrics_updated_at" BEFORE UPDATE ON "rehab"."session_metrics" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_sessions_updated_at" BEFORE UPDATE ON "rehab"."sessions" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_device_assignments_updated_at" BEFORE UPDATE ON "telemetry"."device_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



CREATE OR REPLACE TRIGGER "trg_devices_updated_at" BEFORE UPDATE ON "telemetry"."devices" FOR EACH ROW EXECUTE FUNCTION "public"."touch_updated_at"();



ALTER TABLE ONLY "accounts"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "accounts"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."patient_profiles"
    ADD CONSTRAINT "patient_profiles_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "accounts"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."pt_patient_map"
    ADD CONSTRAINT "pt_patient_map_patient_profile_id_fkey" FOREIGN KEY ("patient_profile_id") REFERENCES "accounts"."patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."pt_patient_map"
    ADD CONSTRAINT "pt_patient_map_pt_profile_id_fkey" FOREIGN KEY ("pt_profile_id") REFERENCES "accounts"."pt_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."pt_profiles"
    ADD CONSTRAINT "pt_profiles_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "accounts"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."rehab_plans"
    ADD CONSTRAINT "rehab_plans_patient_profile_id_fkey" FOREIGN KEY ("patient_profile_id") REFERENCES "accounts"."patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "accounts"."rehab_plans"
    ADD CONSTRAINT "rehab_plans_pt_profile_id_fkey" FOREIGN KEY ("pt_profile_id") REFERENCES "accounts"."pt_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "content"."assets"
    ADD CONSTRAINT "assets_linked_session_id_fkey" FOREIGN KEY ("linked_session_id") REFERENCES "rehab"."sessions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "content"."assets"
    ADD CONSTRAINT "assets_uploader_profile_id_fkey" FOREIGN KEY ("uploader_profile_id") REFERENCES "accounts"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "content"."lesson_assets"
    ADD CONSTRAINT "lesson_assets_asset_id_fkey" FOREIGN KEY ("asset_id") REFERENCES "content"."assets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "content"."lesson_assets"
    ADD CONSTRAINT "lesson_assets_plan_lesson_id_fkey" FOREIGN KEY ("plan_lesson_id") REFERENCES "rehab"."plan_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."lesson_progress"
    ADD CONSTRAINT "lesson_progress_plan_assignment_id_fkey" FOREIGN KEY ("plan_assignment_id") REFERENCES "rehab"."plan_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."lesson_progress"
    ADD CONSTRAINT "lesson_progress_plan_lesson_id_fkey" FOREIGN KEY ("plan_lesson_id") REFERENCES "rehab"."plan_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."plan_assignments"
    ADD CONSTRAINT "plan_assignments_patient_profile_id_fkey" FOREIGN KEY ("patient_profile_id") REFERENCES "accounts"."patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."plan_assignments"
    ADD CONSTRAINT "plan_assignments_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "rehab"."plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."plan_assignments"
    ADD CONSTRAINT "plan_assignments_pt_profile_id_fkey" FOREIGN KEY ("pt_profile_id") REFERENCES "accounts"."pt_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."plan_lessons"
    ADD CONSTRAINT "plan_lessons_exercise_id_fkey" FOREIGN KEY ("exercise_id") REFERENCES "rehab"."exercises"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "rehab"."plan_lessons"
    ADD CONSTRAINT "plan_lessons_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "rehab"."plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."plan_schedule_slots"
    ADD CONSTRAINT "plan_schedule_slots_plan_assignment_id_fkey" FOREIGN KEY ("plan_assignment_id") REFERENCES "rehab"."plan_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."plans"
    ADD CONSTRAINT "plans_created_by_pt_profile_id_fkey" FOREIGN KEY ("created_by_pt_profile_id") REFERENCES "accounts"."pt_profiles"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "rehab"."session_metrics"
    ADD CONSTRAINT "session_metrics_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "rehab"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."sessions"
    ADD CONSTRAINT "sessions_plan_assignment_id_fkey" FOREIGN KEY ("plan_assignment_id") REFERENCES "rehab"."plan_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "rehab"."sessions"
    ADD CONSTRAINT "sessions_plan_lesson_id_fkey" FOREIGN KEY ("plan_lesson_id") REFERENCES "rehab"."plan_lessons"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "telemetry"."calibrations"
    ADD CONSTRAINT "calibrations_device_assignment_id_fkey" FOREIGN KEY ("device_assignment_id") REFERENCES "telemetry"."device_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "telemetry"."device_assignments"
    ADD CONSTRAINT "device_assignments_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "telemetry"."devices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "telemetry"."device_assignments"
    ADD CONSTRAINT "device_assignments_patient_profile_id_fkey" FOREIGN KEY ("patient_profile_id") REFERENCES "accounts"."patient_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "telemetry"."device_assignments"
    ADD CONSTRAINT "device_assignments_pt_profile_id_fkey" FOREIGN KEY ("pt_profile_id") REFERENCES "accounts"."pt_profiles"("id");



ALTER TABLE ONLY "telemetry"."session_samples"
    ADD CONSTRAINT "session_samples_device_assignment_id_fkey" FOREIGN KEY ("device_assignment_id") REFERENCES "telemetry"."device_assignments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "telemetry"."session_samples"
    ADD CONSTRAINT "session_samples_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "rehab"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE "accounts"."admin_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_profiles_access" ON "accounts"."admin_profiles" USING ("accounts"."is_admin"()) WITH CHECK ("accounts"."is_admin"());



ALTER TABLE "accounts"."patient_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "patient_profiles_insert_by_pt" ON "accounts"."patient_profiles" FOR INSERT TO "authenticated" WITH CHECK ("accounts"."is_pt"());



CREATE POLICY "patient_profiles_patient_self_select" ON "accounts"."patient_profiles" FOR SELECT TO "authenticated" USING (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "patient_profiles_patient_self_update" ON "accounts"."patient_profiles" FOR UPDATE TO "authenticated" USING (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())))) WITH CHECK (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "patient_profiles_pt_owner_select" ON "accounts"."patient_profiles" FOR SELECT TO "authenticated" USING (("accounts"."is_pt_owner_of"("id") OR "accounts"."is_pt"()));



CREATE POLICY "patient_profiles_pt_owner_update" ON "accounts"."patient_profiles" FOR UPDATE TO "authenticated" USING (("accounts"."is_pt_owner_of"("id") OR "accounts"."is_pt"())) WITH CHECK (("accounts"."is_pt_owner_of"("id") OR "accounts"."is_pt"()));



ALTER TABLE "accounts"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_self" ON "accounts"."profiles" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "profiles_select_self" ON "accounts"."profiles" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "profiles_update_self" ON "accounts"."profiles" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "accounts"."pt_patient_map" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pt_patient_map_delete_owner" ON "accounts"."pt_patient_map" FOR DELETE TO "authenticated" USING (("accounts"."is_pt_owner_of"("patient_profile_id") OR "accounts"."is_pt"()));



CREATE POLICY "pt_patient_map_insert_owner" ON "accounts"."pt_patient_map" FOR INSERT TO "authenticated" WITH CHECK (("accounts"."is_pt"() AND ("pt_profile_id" = "accounts"."current_pt_profile_id"())));



CREATE POLICY "pt_patient_map_select_owner" ON "accounts"."pt_patient_map" FOR SELECT TO "authenticated" USING (("accounts"."is_pt_owner_of"("patient_profile_id") OR "accounts"."is_pt"()));



CREATE POLICY "pt_patient_map_update_owner" ON "accounts"."pt_patient_map" FOR UPDATE TO "authenticated" USING (("accounts"."is_pt_owner_of"("patient_profile_id") OR "accounts"."is_pt"())) WITH CHECK (("accounts"."is_pt_owner_of"("patient_profile_id") OR "accounts"."is_pt"()));



ALTER TABLE "accounts"."pt_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pt_profiles_insert_owner" ON "accounts"."pt_profiles" FOR INSERT TO "authenticated" WITH CHECK (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "pt_profiles_select_owner" ON "accounts"."pt_profiles" FOR SELECT TO "authenticated" USING (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



CREATE POLICY "pt_profiles_update_owner" ON "accounts"."pt_profiles" FOR UPDATE TO "authenticated" USING (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"())))) WITH CHECK (("profile_id" IN ( SELECT "profiles"."id"
   FROM "accounts"."profiles"
  WHERE ("profiles"."user_id" = "auth"."uid"()))));



ALTER TABLE "content"."assets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "assets_access" ON "content"."assets" USING (("accounts"."is_admin"() OR ("uploader_profile_id" = "accounts"."current_profile_id"()) OR ("accounts"."is_pt"() AND (EXISTS ( SELECT 1
   FROM ("rehab"."sessions" "s"
     JOIN "rehab"."plan_assignments" "pa" ON (("pa"."id" = "s"."plan_assignment_id")))
  WHERE (("s"."id" = "assets"."linked_session_id") AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"()))))) OR ("accounts"."is_patient"() AND (EXISTS ( SELECT 1
   FROM ("rehab"."sessions" "s"
     JOIN "rehab"."plan_assignments" "pa" ON (("pa"."id" = "s"."plan_assignment_id")))
  WHERE (("s"."id" = "assets"."linked_session_id") AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))) WITH CHECK (("accounts"."is_admin"() OR ("uploader_profile_id" = "accounts"."current_profile_id"())));



ALTER TABLE "content"."lesson_assets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "lesson_assets_access" ON "content"."lesson_assets" USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("rehab"."plan_lessons" "pl"
     JOIN "rehab"."plans" "p" ON (("p"."id" = "pl"."plan_id")))
  WHERE (("pl"."id" = "lesson_assets"."plan_lesson_id") AND (("accounts"."is_pt"() AND ("p"."created_by_pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND (EXISTS ( SELECT 1
           FROM "rehab"."plan_assignments" "pa"
          WHERE (("pa"."plan_id" = "pl"."plan_id") AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))))))) WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("rehab"."plan_lessons" "pl"
     JOIN "rehab"."plans" "p" ON (("p"."id" = "pl"."plan_id")))
  WHERE (("pl"."id" = "lesson_assets"."plan_lesson_id") AND (("accounts"."is_pt"() AND ("p"."created_by_pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND (EXISTS ( SELECT 1
           FROM "rehab"."plan_assignments" "pa"
          WHERE (("pa"."plan_id" = "pl"."plan_id") AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))))))));



ALTER TABLE "rehab"."exercises" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "exercises_read_all" ON "rehab"."exercises" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "rehab"."lesson_progress" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "lesson_progress_access" ON "rehab"."lesson_progress" USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."id" = "lesson_progress"."plan_assignment_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))))) WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."id" = "lesson_progress"."plan_assignment_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));



ALTER TABLE "rehab"."plan_assignments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "plan_assignments_manage_pt" ON "rehab"."plan_assignments" USING (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "pt_profile_id")))) WITH CHECK (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "pt_profile_id"))));



CREATE POLICY "plan_assignments_select_accessible" ON "rehab"."plan_assignments" FOR SELECT USING (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "pt_profile_id")) OR ("accounts"."is_patient"() AND ("accounts"."current_patient_profile_id"() = "patient_profile_id"))));



ALTER TABLE "rehab"."plan_lessons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "plan_lessons_access" ON "rehab"."plan_lessons" USING (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND (EXISTS ( SELECT 1
   FROM "rehab"."plans"
  WHERE (("plans"."id" = "plan_lessons"."plan_id") AND ("plans"."created_by_pt_profile_id" = "accounts"."current_pt_profile_id"()))))) OR ("accounts"."is_patient"() AND (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."plan_id" = "plan_lessons"."plan_id") AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))) WITH CHECK (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND (EXISTS ( SELECT 1
   FROM "rehab"."plans"
  WHERE (("plans"."id" = "plan_lessons"."plan_id") AND ("plans"."created_by_pt_profile_id" = "accounts"."current_pt_profile_id"())))))));



ALTER TABLE "rehab"."plan_schedule_slots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "rehab"."plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "plans_manage_owner" ON "rehab"."plans" USING (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "created_by_pt_profile_id")))) WITH CHECK (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "created_by_pt_profile_id"))));



CREATE POLICY "plans_select_accessible" ON "rehab"."plans" FOR SELECT USING (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "created_by_pt_profile_id")) OR ("accounts"."is_patient"() AND (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."plan_id" = "plans"."id") AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))));



CREATE POLICY "schedule_slots_access" ON "rehab"."plan_schedule_slots" USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."id" = "plan_schedule_slots"."plan_assignment_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))))) WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."id" = "plan_schedule_slots"."plan_assignment_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));



ALTER TABLE "rehab"."session_metrics" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "session_metrics_access" ON "rehab"."session_metrics" USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("rehab"."sessions" "s"
     JOIN "rehab"."plan_assignments" "pa" ON (("pa"."id" = "s"."plan_assignment_id")))
  WHERE (("s"."id" = "session_metrics"."session_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))))) WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("rehab"."sessions" "s"
     JOIN "rehab"."plan_assignments" "pa" ON (("pa"."id" = "s"."plan_assignment_id")))
  WHERE (("s"."id" = "session_metrics"."session_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));



ALTER TABLE "rehab"."sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sessions_access" ON "rehab"."sessions" USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."id" = "sessions"."plan_assignment_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))))) WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "rehab"."plan_assignments" "pa"
  WHERE (("pa"."id" = "sessions"."plan_assignment_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));



ALTER TABLE "telemetry"."calibrations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "calibrations_access" ON "telemetry"."calibrations" USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "telemetry"."device_assignments" "da"
  WHERE (("da"."id" = "calibrations"."device_assignment_id") AND (("accounts"."is_pt"() AND ("da"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("da"."patient_profile_id" = "accounts"."current_patient_profile_id"())))))))) WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "telemetry"."device_assignments" "da"
  WHERE (("da"."id" = "calibrations"."device_assignment_id") AND (("accounts"."is_pt"() AND ("da"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("da"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));



ALTER TABLE "telemetry"."device_assignments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "device_assignments_access" ON "telemetry"."device_assignments" USING (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "pt_profile_id")) OR ("accounts"."is_patient"() AND ("accounts"."current_patient_profile_id"() = "patient_profile_id")))) WITH CHECK (("accounts"."is_admin"() OR ("accounts"."is_pt"() AND ("accounts"."current_pt_profile_id"() = "pt_profile_id")) OR ("accounts"."is_patient"() AND ("accounts"."current_patient_profile_id"() = "patient_profile_id"))));



ALTER TABLE "telemetry"."devices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "devices_manage_admin" ON "telemetry"."devices" USING ("accounts"."is_admin"()) WITH CHECK ("accounts"."is_admin"());



CREATE POLICY "devices_read" ON "telemetry"."devices" FOR SELECT USING (("accounts"."is_admin"() OR "accounts"."is_pt"()));



ALTER TABLE "telemetry"."session_samples" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "session_samples_access" ON "telemetry"."session_samples" FOR SELECT USING (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("rehab"."sessions" "s"
     JOIN "rehab"."plan_assignments" "pa" ON (("pa"."id" = "s"."plan_assignment_id")))
  WHERE (("s"."id" = "session_samples"."session_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));



CREATE POLICY "session_samples_insert_by_device_owner" ON "telemetry"."session_samples" FOR INSERT WITH CHECK (("accounts"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("rehab"."sessions" "s"
     JOIN "rehab"."plan_assignments" "pa" ON (("pa"."id" = "s"."plan_assignment_id")))
  WHERE (("s"."id" = "session_samples"."session_id") AND (("accounts"."is_pt"() AND ("pa"."pt_profile_id" = "accounts"."current_pt_profile_id"())) OR ("accounts"."is_patient"() AND ("pa"."patient_profile_id" = "accounts"."current_patient_profile_id"()))))))));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "accounts" TO "authenticated";
GRANT USAGE ON SCHEMA "accounts" TO "anon";



GRANT USAGE ON SCHEMA "content" TO "authenticated";
GRANT USAGE ON SCHEMA "content" TO "anon";



REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "anon";



GRANT USAGE ON SCHEMA "rehab" TO "authenticated";
GRANT USAGE ON SCHEMA "rehab" TO "anon";



GRANT USAGE ON SCHEMA "telemetry" TO "authenticated";
GRANT USAGE ON SCHEMA "telemetry" TO "anon";



REVOKE ALL ON FUNCTION "accounts"."current_pt_profile_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "accounts"."current_pt_profile_id"() TO "authenticated";



GRANT ALL ON FUNCTION "accounts"."is_current_user_pt"() TO "authenticated";



GRANT ALL ON FUNCTION "accounts"."is_patient_mapped_to_current_pt"("patient_profile_id_uuid" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "accounts"."is_pt"() FROM PUBLIC;
GRANT ALL ON FUNCTION "accounts"."is_pt"() TO "anon";
GRANT ALL ON FUNCTION "accounts"."is_pt"() TO "authenticated";



GRANT ALL ON FUNCTION "accounts"."is_pt_owned"("pt_profile_id_uuid" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "accounts"."is_pt_owner_of"("patient_profile" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "accounts"."is_pt_owner_of"("patient_profile" "uuid") TO "authenticated";


































































































































































GRANT SELECT,INSERT,UPDATE ON TABLE "accounts"."patient_profiles" TO "authenticated";



GRANT SELECT,INSERT,UPDATE ON TABLE "accounts"."profiles" TO "authenticated";



GRANT SELECT,INSERT,UPDATE ON TABLE "accounts"."pt_patient_map" TO "authenticated";



GRANT SELECT,INSERT,UPDATE ON TABLE "accounts"."pt_profiles" TO "authenticated";








































drop extension if exists "pg_net";


