drop extension if exists "pg_net";

create schema if not exists "accounts";

create schema if not exists "content";

create schema if not exists "rehab";

create schema if not exists "telemetry";

create extension if not exists "citext" with schema "public";

create type "accounts"."assignment_status" as enum ('pending', 'active', 'suspended', 'archived');

create type "accounts"."gender" as enum ('female', 'male', 'non_binary', 'prefer_not_to_say', 'other');

create type "accounts"."user_role" as enum ('patient', 'pt', 'admin');

create type "content"."asset_purpose" as enum ('session_upload', 'lesson_reference', 'plan_resource');

create type "content"."asset_status" as enum ('pending', 'available', 'processing', 'failed');

create type "rehab"."exercise_difficulty" as enum ('beginner', 'intermediate', 'advanced');

create type "rehab"."lesson_phase" as enum ('phase_1', 'phase_2', 'phase_3', 'phase_4');

create type "rehab"."plan_status" as enum ('draft', 'active', 'suspended', 'completed', 'archived');

create type "rehab"."session_status" as enum ('scheduled', 'in_progress', 'completed', 'aborted');

create type "telemetry"."calibration_stage" as enum ('starting_position', 'maximum_position', 'full_range');

create type "telemetry"."device_status" as enum ('unpaired', 'paired', 'maintenance', 'retired');


  create table "accounts"."admin_profiles" (
    "id" uuid not null default gen_random_uuid(),
    "profile_id" uuid not null,
    "title" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "accounts"."admin_profiles" enable row level security;


  create table "accounts"."patient_profiles" (
    "id" uuid not null default gen_random_uuid(),
    "profile_id" uuid,
    "date_of_birth" date,
    "gender" accounts.gender,
    "surgery_date" date,
    "last_pt_visit" date,
    "allow_notifications" boolean not null default true,
    "allow_camera" boolean not null default true,
    "intake_notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "phone" text,
    "first_name" text,
    "last_name" text,
    "access_code" text
      );


alter table "accounts"."patient_profiles" enable row level security;


  create table "accounts"."profiles" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "role" accounts.user_role not null,
    "email" public.citext not null,
    "first_name" text not null,
    "last_name" text not null,
    "phone" text,
    "timezone" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "accounts"."profiles" enable row level security;


  create table "accounts"."pt_patient_map" (
    "id" uuid not null default gen_random_uuid(),
    "patient_profile_id" uuid not null,
    "pt_profile_id" uuid not null,
    "status" accounts.assignment_status not null default 'pending'::accounts.assignment_status,
    "assigned_at" timestamp with time zone not null default now(),
    "accepted_at" timestamp with time zone,
    "archived_at" timestamp with time zone,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "accounts"."pt_patient_map" enable row level security;


  create table "accounts"."pt_profiles" (
    "id" uuid not null default gen_random_uuid(),
    "profile_id" uuid,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "email" text,
    "first_name" text,
    "last_name" text,
    "phone" text,
    "license_number" text,
    "npi_number" text,
    "practice_name" text,
    "practice_address" text,
    "specialization" text
      );


alter table "accounts"."pt_profiles" enable row level security;


  create table "accounts"."rehab_plans" (
    "id" uuid not null default extensions.uuid_generate_v4(),
    "pt_profile_id" uuid not null,
    "patient_profile_id" uuid not null,
    "category" text not null,
    "injury" text not null,
    "status" text not null default 'active'::text,
    "created_at" timestamp with time zone not null default now(),
    "nodes" jsonb,
    "notes" text
      );


alter table "accounts"."rehab_plans" enable row level security;


  create table "content"."assets" (
    "id" uuid not null default gen_random_uuid(),
    "uploader_profile_id" uuid not null,
    "status" content.asset_status not null default 'pending'::content.asset_status,
    "purpose" content.asset_purpose not null default 'session_upload'::content.asset_purpose,
    "storage_path" text not null,
    "file_name" text,
    "content_type" text,
    "duration_seconds" numeric(8,2),
    "file_size_bytes" bigint,
    "linked_session_id" uuid,
    "metadata" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "content"."assets" enable row level security;


  create table "content"."lesson_assets" (
    "id" uuid not null default gen_random_uuid(),
    "plan_lesson_id" uuid not null,
    "asset_id" uuid not null,
    "is_primary" boolean not null default false,
    "created_at" timestamp with time zone not null default now()
      );


alter table "content"."lesson_assets" enable row level security;


  create table "rehab"."exercises" (
    "id" uuid not null default gen_random_uuid(),
    "slug" text not null,
    "display_name" text not null,
    "description" text,
    "body_region" text,
    "difficulty" rehab.exercise_difficulty not null default 'beginner'::rehab.exercise_difficulty,
    "default_reps" integer,
    "default_rest_seconds" integer,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."exercises" enable row level security;


  create table "rehab"."lesson_progress" (
    "id" uuid not null default gen_random_uuid(),
    "plan_assignment_id" uuid not null,
    "plan_lesson_id" uuid not null,
    "unlocked_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "last_session_id" uuid,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."lesson_progress" enable row level security;


  create table "rehab"."plan_assignments" (
    "id" uuid not null default gen_random_uuid(),
    "plan_id" uuid not null,
    "patient_profile_id" uuid not null,
    "pt_profile_id" uuid not null,
    "started_on" date,
    "completed_on" date,
    "allow_reminders" boolean not null default true,
    "allow_camera" boolean not null default true,
    "timezone" text,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."plan_assignments" enable row level security;


  create table "rehab"."plan_lessons" (
    "id" uuid not null default gen_random_uuid(),
    "plan_id" uuid not null,
    "exercise_id" uuid,
    "phase" rehab.lesson_phase not null default 'phase_1'::rehab.lesson_phase,
    "title" text,
    "icon_name" text,
    "is_locked" boolean not null default false,
    "reps" integer,
    "rest_seconds" integer,
    "sequence_position" integer not null,
    "video_url" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."plan_lessons" enable row level security;


  create table "rehab"."plan_schedule_slots" (
    "id" uuid not null default gen_random_uuid(),
    "plan_assignment_id" uuid not null,
    "day_of_week" smallint not null,
    "slot_time" time without time zone not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "rehab"."plan_schedule_slots" enable row level security;


  create table "rehab"."plans" (
    "id" uuid not null default gen_random_uuid(),
    "title" text not null,
    "injury_focus" text not null default 'ACL Tear Recovery'::text,
    "status" rehab.plan_status not null default 'draft'::rehab.plan_status,
    "created_by_pt_profile_id" uuid not null,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."plans" enable row level security;


  create table "rehab"."session_metrics" (
    "id" uuid not null default gen_random_uuid(),
    "session_id" uuid not null,
    "total_reps" integer,
    "accuracy_percent" numeric(5,2),
    "range_of_motion_deg" numeric(6,2),
    "session_duration_seconds" integer,
    "average_flex_value" numeric(8,4),
    "peak_flex_value" numeric(8,4),
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."session_metrics" enable row level security;


  create table "rehab"."sessions" (
    "id" uuid not null default gen_random_uuid(),
    "plan_assignment_id" uuid not null,
    "plan_lesson_id" uuid not null,
    "status" rehab.session_status not null default 'scheduled'::rehab.session_status,
    "scheduled_for" timestamp with time zone,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "expected_reps" integer,
    "expected_rest_seconds" integer,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "rehab"."sessions" enable row level security;


  create table "telemetry"."calibrations" (
    "id" uuid not null default gen_random_uuid(),
    "device_assignment_id" uuid not null,
    "stage" telemetry.calibration_stage not null,
    "recorded_at" timestamp with time zone not null default now(),
    "flex_value" numeric(8,4),
    "knee_angle_deg" numeric(6,2),
    "notes" text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "telemetry"."calibrations" enable row level security;


  create table "telemetry"."device_assignments" (
    "id" uuid not null default gen_random_uuid(),
    "device_id" uuid not null,
    "patient_profile_id" uuid not null,
    "pt_profile_id" uuid,
    "paired_at" timestamp with time zone not null default now(),
    "unpaired_at" timestamp with time zone,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "telemetry"."devices" (
    "id" uuid not null default gen_random_uuid(),
    "hardware_serial" text not null,
    "firmware_version" text,
    "status" telemetry.device_status not null default 'unpaired'::telemetry.device_status,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "telemetry"."devices" enable row level security;


  create table "telemetry"."session_samples" (
    "id" uuid not null default gen_random_uuid(),
    "session_id" uuid not null,
    "device_assignment_id" uuid,
    "recorded_at" timestamp with time zone not null,
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
    "created_at" timestamp with time zone not null default now()
      );


alter table "telemetry"."session_samples" enable row level security;

CREATE UNIQUE INDEX admin_profiles_pkey ON accounts.admin_profiles USING btree (id);

CREATE UNIQUE INDEX admin_profiles_profile_id_key ON accounts.admin_profiles USING btree (profile_id);

CREATE UNIQUE INDEX idx_patient_profiles_access_code ON accounts.patient_profiles USING btree (access_code) WHERE (access_code IS NOT NULL);

CREATE INDEX idx_profiles_role ON accounts.profiles USING btree (role);

CREATE INDEX idx_pt_patient_map_patient ON accounts.pt_patient_map USING btree (patient_profile_id);

CREATE UNIQUE INDEX idx_pt_patient_map_patient_profile_id_unique ON accounts.pt_patient_map USING btree (patient_profile_id);

CREATE INDEX idx_pt_patient_map_pt ON accounts.pt_patient_map USING btree (pt_profile_id);

CREATE INDEX idx_pt_patient_map_status ON accounts.pt_patient_map USING btree (status);

CREATE INDEX idx_rehab_plans_pt_patient ON accounts.rehab_plans USING btree (pt_profile_id, patient_profile_id);

CREATE UNIQUE INDEX patient_profiles_pkey ON accounts.patient_profiles USING btree (id);

CREATE UNIQUE INDEX patient_profiles_profile_id_key ON accounts.patient_profiles USING btree (profile_id);

CREATE UNIQUE INDEX patient_profiles_profile_id_unique ON accounts.patient_profiles USING btree (profile_id);

CREATE UNIQUE INDEX profiles_email_key ON accounts.profiles USING btree (email);

CREATE UNIQUE INDEX profiles_pkey ON accounts.profiles USING btree (id);

CREATE UNIQUE INDEX profiles_user_id_key ON accounts.profiles USING btree (user_id);

CREATE UNIQUE INDEX pt_patient_map_patient_profile_id_pt_profile_id_key ON accounts.pt_patient_map USING btree (patient_profile_id, pt_profile_id);

CREATE UNIQUE INDEX pt_patient_map_pkey ON accounts.pt_patient_map USING btree (id);

CREATE UNIQUE INDEX pt_profiles_email_unique ON accounts.pt_profiles USING btree (email);

CREATE UNIQUE INDEX pt_profiles_pkey ON accounts.pt_profiles USING btree (id);

CREATE UNIQUE INDEX pt_profiles_profile_id_key ON accounts.pt_profiles USING btree (profile_id);

CREATE UNIQUE INDEX pt_profiles_profile_id_unique ON accounts.pt_profiles USING btree (profile_id);

CREATE UNIQUE INDEX rehab_plans_pkey ON accounts.rehab_plans USING btree (id);

CREATE UNIQUE INDEX uniq_active_plan_per_patient ON accounts.rehab_plans USING btree (patient_profile_id) WHERE (status = 'active'::text);

CREATE UNIQUE INDEX assets_pkey ON content.assets USING btree (id);

CREATE UNIQUE INDEX assets_storage_path_key ON content.assets USING btree (storage_path);

CREATE INDEX idx_assets_session ON content.assets USING btree (linked_session_id);

CREATE INDEX idx_assets_uploader ON content.assets USING btree (uploader_profile_id);

CREATE INDEX idx_lesson_assets_lesson ON content.lesson_assets USING btree (plan_lesson_id);

CREATE UNIQUE INDEX lesson_assets_pkey ON content.lesson_assets USING btree (id);

CREATE UNIQUE INDEX lesson_assets_plan_lesson_id_asset_id_key ON content.lesson_assets USING btree (plan_lesson_id, asset_id);

CREATE UNIQUE INDEX exercises_pkey ON rehab.exercises USING btree (id);

CREATE UNIQUE INDEX exercises_slug_key ON rehab.exercises USING btree (slug);

CREATE INDEX idx_plan_assignments_patient ON rehab.plan_assignments USING btree (patient_profile_id);

CREATE INDEX idx_plan_assignments_pt ON rehab.plan_assignments USING btree (pt_profile_id);

CREATE INDEX idx_plan_lessons_exercise ON rehab.plan_lessons USING btree (exercise_id);

CREATE INDEX idx_plan_lessons_plan ON rehab.plan_lessons USING btree (plan_id);

CREATE INDEX idx_plan_schedule_slots_assignment ON rehab.plan_schedule_slots USING btree (plan_assignment_id);

CREATE INDEX idx_plan_schedule_slots_day ON rehab.plan_schedule_slots USING btree (day_of_week);

CREATE INDEX idx_plans_created_by_pt ON rehab.plans USING btree (created_by_pt_profile_id);

CREATE INDEX idx_plans_status ON rehab.plans USING btree (status);

CREATE INDEX idx_sessions_assignment ON rehab.sessions USING btree (plan_assignment_id);

CREATE INDEX idx_sessions_lesson ON rehab.sessions USING btree (plan_lesson_id);

CREATE INDEX idx_sessions_status ON rehab.sessions USING btree (status);

CREATE UNIQUE INDEX lesson_progress_pkey ON rehab.lesson_progress USING btree (id);

CREATE UNIQUE INDEX lesson_progress_plan_assignment_id_plan_lesson_id_key ON rehab.lesson_progress USING btree (plan_assignment_id, plan_lesson_id);

CREATE UNIQUE INDEX plan_assignments_pkey ON rehab.plan_assignments USING btree (id);

CREATE UNIQUE INDEX plan_assignments_plan_id_patient_profile_id_key ON rehab.plan_assignments USING btree (plan_id, patient_profile_id);

CREATE UNIQUE INDEX plan_lessons_pkey ON rehab.plan_lessons USING btree (id);

CREATE UNIQUE INDEX plan_lessons_plan_id_sequence_position_key ON rehab.plan_lessons USING btree (plan_id, sequence_position);

CREATE UNIQUE INDEX plan_schedule_slots_pkey ON rehab.plan_schedule_slots USING btree (id);

CREATE UNIQUE INDEX plans_pkey ON rehab.plans USING btree (id);

CREATE UNIQUE INDEX session_metrics_pkey ON rehab.session_metrics USING btree (id);

CREATE UNIQUE INDEX session_metrics_session_id_key ON rehab.session_metrics USING btree (session_id);

CREATE UNIQUE INDEX sessions_pkey ON rehab.sessions USING btree (id);

CREATE UNIQUE INDEX calibrations_pkey ON telemetry.calibrations USING btree (id);

CREATE UNIQUE INDEX device_assignments_pkey ON telemetry.device_assignments USING btree (id);

CREATE UNIQUE INDEX devices_hardware_serial_key ON telemetry.devices USING btree (hardware_serial);

CREATE UNIQUE INDEX devices_pkey ON telemetry.devices USING btree (id);

CREATE INDEX idx_calibrations_assignment ON telemetry.calibrations USING btree (device_assignment_id);

CREATE INDEX idx_calibrations_stage ON telemetry.calibrations USING btree (stage);

CREATE INDEX idx_device_assignments_device ON telemetry.device_assignments USING btree (device_id);

CREATE INDEX idx_device_assignments_patient ON telemetry.device_assignments USING btree (patient_profile_id);

CREATE INDEX idx_session_samples_recorded_at ON telemetry.session_samples USING btree (session_id, recorded_at);

CREATE INDEX idx_session_samples_session ON telemetry.session_samples USING btree (session_id);

CREATE UNIQUE INDEX session_samples_pkey ON telemetry.session_samples USING btree (id);

CREATE UNIQUE INDEX uniq_device_active_assignment ON telemetry.device_assignments USING btree (device_id) WHERE is_active;

alter table "accounts"."admin_profiles" add constraint "admin_profiles_pkey" PRIMARY KEY using index "admin_profiles_pkey";

alter table "accounts"."patient_profiles" add constraint "patient_profiles_pkey" PRIMARY KEY using index "patient_profiles_pkey";

alter table "accounts"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "accounts"."pt_patient_map" add constraint "pt_patient_map_pkey" PRIMARY KEY using index "pt_patient_map_pkey";

alter table "accounts"."pt_profiles" add constraint "pt_profiles_pkey" PRIMARY KEY using index "pt_profiles_pkey";

alter table "accounts"."rehab_plans" add constraint "rehab_plans_pkey" PRIMARY KEY using index "rehab_plans_pkey";

alter table "content"."assets" add constraint "assets_pkey" PRIMARY KEY using index "assets_pkey";

alter table "content"."lesson_assets" add constraint "lesson_assets_pkey" PRIMARY KEY using index "lesson_assets_pkey";

alter table "rehab"."exercises" add constraint "exercises_pkey" PRIMARY KEY using index "exercises_pkey";

alter table "rehab"."lesson_progress" add constraint "lesson_progress_pkey" PRIMARY KEY using index "lesson_progress_pkey";

alter table "rehab"."plan_assignments" add constraint "plan_assignments_pkey" PRIMARY KEY using index "plan_assignments_pkey";

alter table "rehab"."plan_lessons" add constraint "plan_lessons_pkey" PRIMARY KEY using index "plan_lessons_pkey";

alter table "rehab"."plan_schedule_slots" add constraint "plan_schedule_slots_pkey" PRIMARY KEY using index "plan_schedule_slots_pkey";

alter table "rehab"."plans" add constraint "plans_pkey" PRIMARY KEY using index "plans_pkey";

alter table "rehab"."session_metrics" add constraint "session_metrics_pkey" PRIMARY KEY using index "session_metrics_pkey";

alter table "rehab"."sessions" add constraint "sessions_pkey" PRIMARY KEY using index "sessions_pkey";

alter table "telemetry"."calibrations" add constraint "calibrations_pkey" PRIMARY KEY using index "calibrations_pkey";

alter table "telemetry"."device_assignments" add constraint "device_assignments_pkey" PRIMARY KEY using index "device_assignments_pkey";

alter table "telemetry"."devices" add constraint "devices_pkey" PRIMARY KEY using index "devices_pkey";

alter table "telemetry"."session_samples" add constraint "session_samples_pkey" PRIMARY KEY using index "session_samples_pkey";

alter table "accounts"."admin_profiles" add constraint "admin_profiles_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES accounts.profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."admin_profiles" validate constraint "admin_profiles_profile_id_fkey";

alter table "accounts"."admin_profiles" add constraint "admin_profiles_profile_id_key" UNIQUE using index "admin_profiles_profile_id_key";

alter table "accounts"."patient_profiles" add constraint "patient_profiles_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES accounts.profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."patient_profiles" validate constraint "patient_profiles_profile_id_fkey";

alter table "accounts"."patient_profiles" add constraint "patient_profiles_profile_id_key" UNIQUE using index "patient_profiles_profile_id_key";

alter table "accounts"."patient_profiles" add constraint "patient_profiles_profile_id_unique" UNIQUE using index "patient_profiles_profile_id_unique";

alter table "accounts"."profiles" add constraint "profiles_email_key" UNIQUE using index "profiles_email_key";

alter table "accounts"."profiles" add constraint "profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "accounts"."profiles" validate constraint "profiles_user_id_fkey";

alter table "accounts"."profiles" add constraint "profiles_user_id_key" UNIQUE using index "profiles_user_id_key";

alter table "accounts"."pt_patient_map" add constraint "pt_patient_map_patient_profile_id_fkey" FOREIGN KEY (patient_profile_id) REFERENCES accounts.patient_profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."pt_patient_map" validate constraint "pt_patient_map_patient_profile_id_fkey";

alter table "accounts"."pt_patient_map" add constraint "pt_patient_map_patient_profile_id_pt_profile_id_key" UNIQUE using index "pt_patient_map_patient_profile_id_pt_profile_id_key";

alter table "accounts"."pt_patient_map" add constraint "pt_patient_map_pt_profile_id_fkey" FOREIGN KEY (pt_profile_id) REFERENCES accounts.pt_profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."pt_patient_map" validate constraint "pt_patient_map_pt_profile_id_fkey";

alter table "accounts"."pt_profiles" add constraint "pt_profiles_email_unique" UNIQUE using index "pt_profiles_email_unique";

alter table "accounts"."pt_profiles" add constraint "pt_profiles_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES accounts.profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."pt_profiles" validate constraint "pt_profiles_profile_id_fkey";

alter table "accounts"."pt_profiles" add constraint "pt_profiles_profile_id_key" UNIQUE using index "pt_profiles_profile_id_key";

alter table "accounts"."pt_profiles" add constraint "pt_profiles_profile_id_unique" UNIQUE using index "pt_profiles_profile_id_unique";

alter table "accounts"."rehab_plans" add constraint "rehab_plans_patient_profile_id_fkey" FOREIGN KEY (patient_profile_id) REFERENCES accounts.patient_profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."rehab_plans" validate constraint "rehab_plans_patient_profile_id_fkey";

alter table "accounts"."rehab_plans" add constraint "rehab_plans_pt_profile_id_fkey" FOREIGN KEY (pt_profile_id) REFERENCES accounts.pt_profiles(id) ON DELETE CASCADE not valid;

alter table "accounts"."rehab_plans" validate constraint "rehab_plans_pt_profile_id_fkey";

alter table "content"."assets" add constraint "assets_linked_session_id_fkey" FOREIGN KEY (linked_session_id) REFERENCES rehab.sessions(id) ON DELETE SET NULL not valid;

alter table "content"."assets" validate constraint "assets_linked_session_id_fkey";

alter table "content"."assets" add constraint "assets_storage_path_key" UNIQUE using index "assets_storage_path_key";

alter table "content"."assets" add constraint "assets_uploader_profile_id_fkey" FOREIGN KEY (uploader_profile_id) REFERENCES accounts.profiles(id) ON DELETE CASCADE not valid;

alter table "content"."assets" validate constraint "assets_uploader_profile_id_fkey";

alter table "content"."lesson_assets" add constraint "lesson_assets_asset_id_fkey" FOREIGN KEY (asset_id) REFERENCES content.assets(id) ON DELETE CASCADE not valid;

alter table "content"."lesson_assets" validate constraint "lesson_assets_asset_id_fkey";

alter table "content"."lesson_assets" add constraint "lesson_assets_plan_lesson_id_asset_id_key" UNIQUE using index "lesson_assets_plan_lesson_id_asset_id_key";

alter table "content"."lesson_assets" add constraint "lesson_assets_plan_lesson_id_fkey" FOREIGN KEY (plan_lesson_id) REFERENCES rehab.plan_lessons(id) ON DELETE CASCADE not valid;

alter table "content"."lesson_assets" validate constraint "lesson_assets_plan_lesson_id_fkey";

alter table "rehab"."exercises" add constraint "exercises_slug_key" UNIQUE using index "exercises_slug_key";

alter table "rehab"."lesson_progress" add constraint "lesson_progress_plan_assignment_id_fkey" FOREIGN KEY (plan_assignment_id) REFERENCES rehab.plan_assignments(id) ON DELETE CASCADE not valid;

alter table "rehab"."lesson_progress" validate constraint "lesson_progress_plan_assignment_id_fkey";

alter table "rehab"."lesson_progress" add constraint "lesson_progress_plan_assignment_id_plan_lesson_id_key" UNIQUE using index "lesson_progress_plan_assignment_id_plan_lesson_id_key";

alter table "rehab"."lesson_progress" add constraint "lesson_progress_plan_lesson_id_fkey" FOREIGN KEY (plan_lesson_id) REFERENCES rehab.plan_lessons(id) ON DELETE CASCADE not valid;

alter table "rehab"."lesson_progress" validate constraint "lesson_progress_plan_lesson_id_fkey";

alter table "rehab"."plan_assignments" add constraint "plan_assignments_patient_profile_id_fkey" FOREIGN KEY (patient_profile_id) REFERENCES accounts.patient_profiles(id) ON DELETE CASCADE not valid;

alter table "rehab"."plan_assignments" validate constraint "plan_assignments_patient_profile_id_fkey";

alter table "rehab"."plan_assignments" add constraint "plan_assignments_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES rehab.plans(id) ON DELETE CASCADE not valid;

alter table "rehab"."plan_assignments" validate constraint "plan_assignments_plan_id_fkey";

alter table "rehab"."plan_assignments" add constraint "plan_assignments_plan_id_patient_profile_id_key" UNIQUE using index "plan_assignments_plan_id_patient_profile_id_key";

alter table "rehab"."plan_assignments" add constraint "plan_assignments_pt_profile_id_fkey" FOREIGN KEY (pt_profile_id) REFERENCES accounts.pt_profiles(id) ON DELETE CASCADE not valid;

alter table "rehab"."plan_assignments" validate constraint "plan_assignments_pt_profile_id_fkey";

alter table "rehab"."plan_lessons" add constraint "plan_lessons_exercise_id_fkey" FOREIGN KEY (exercise_id) REFERENCES rehab.exercises(id) ON DELETE SET NULL not valid;

alter table "rehab"."plan_lessons" validate constraint "plan_lessons_exercise_id_fkey";

alter table "rehab"."plan_lessons" add constraint "plan_lessons_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES rehab.plans(id) ON DELETE CASCADE not valid;

alter table "rehab"."plan_lessons" validate constraint "plan_lessons_plan_id_fkey";

alter table "rehab"."plan_lessons" add constraint "plan_lessons_plan_id_sequence_position_key" UNIQUE using index "plan_lessons_plan_id_sequence_position_key";

alter table "rehab"."plan_schedule_slots" add constraint "plan_schedule_slots_day_of_week_check" CHECK (((day_of_week >= 0) AND (day_of_week <= 6))) not valid;

alter table "rehab"."plan_schedule_slots" validate constraint "plan_schedule_slots_day_of_week_check";

alter table "rehab"."plan_schedule_slots" add constraint "plan_schedule_slots_plan_assignment_id_fkey" FOREIGN KEY (plan_assignment_id) REFERENCES rehab.plan_assignments(id) ON DELETE CASCADE not valid;

alter table "rehab"."plan_schedule_slots" validate constraint "plan_schedule_slots_plan_assignment_id_fkey";

alter table "rehab"."plans" add constraint "plans_created_by_pt_profile_id_fkey" FOREIGN KEY (created_by_pt_profile_id) REFERENCES accounts.pt_profiles(id) ON DELETE RESTRICT not valid;

alter table "rehab"."plans" validate constraint "plans_created_by_pt_profile_id_fkey";

alter table "rehab"."session_metrics" add constraint "session_metrics_session_id_fkey" FOREIGN KEY (session_id) REFERENCES rehab.sessions(id) ON DELETE CASCADE not valid;

alter table "rehab"."session_metrics" validate constraint "session_metrics_session_id_fkey";

alter table "rehab"."session_metrics" add constraint "session_metrics_session_id_key" UNIQUE using index "session_metrics_session_id_key";

alter table "rehab"."sessions" add constraint "sessions_plan_assignment_id_fkey" FOREIGN KEY (plan_assignment_id) REFERENCES rehab.plan_assignments(id) ON DELETE CASCADE not valid;

alter table "rehab"."sessions" validate constraint "sessions_plan_assignment_id_fkey";

alter table "rehab"."sessions" add constraint "sessions_plan_lesson_id_fkey" FOREIGN KEY (plan_lesson_id) REFERENCES rehab.plan_lessons(id) ON DELETE CASCADE not valid;

alter table "rehab"."sessions" validate constraint "sessions_plan_lesson_id_fkey";

alter table "telemetry"."calibrations" add constraint "calibrations_device_assignment_id_fkey" FOREIGN KEY (device_assignment_id) REFERENCES telemetry.device_assignments(id) ON DELETE CASCADE not valid;

alter table "telemetry"."calibrations" validate constraint "calibrations_device_assignment_id_fkey";

alter table "telemetry"."device_assignments" add constraint "device_assignments_device_id_fkey" FOREIGN KEY (device_id) REFERENCES telemetry.devices(id) ON DELETE CASCADE not valid;

alter table "telemetry"."device_assignments" validate constraint "device_assignments_device_id_fkey";

alter table "telemetry"."device_assignments" add constraint "device_assignments_patient_profile_id_fkey" FOREIGN KEY (patient_profile_id) REFERENCES accounts.patient_profiles(id) ON DELETE CASCADE not valid;

alter table "telemetry"."device_assignments" validate constraint "device_assignments_patient_profile_id_fkey";

alter table "telemetry"."device_assignments" add constraint "device_assignments_pt_profile_id_fkey" FOREIGN KEY (pt_profile_id) REFERENCES accounts.pt_profiles(id) not valid;

alter table "telemetry"."device_assignments" validate constraint "device_assignments_pt_profile_id_fkey";

alter table "telemetry"."devices" add constraint "devices_hardware_serial_key" UNIQUE using index "devices_hardware_serial_key";

alter table "telemetry"."session_samples" add constraint "session_samples_device_assignment_id_fkey" FOREIGN KEY (device_assignment_id) REFERENCES telemetry.device_assignments(id) ON DELETE SET NULL not valid;

alter table "telemetry"."session_samples" validate constraint "session_samples_device_assignment_id_fkey";

alter table "telemetry"."session_samples" add constraint "session_samples_session_id_fkey" FOREIGN KEY (session_id) REFERENCES rehab.sessions(id) ON DELETE CASCADE not valid;

alter table "telemetry"."session_samples" validate constraint "session_samples_session_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION accounts.current_patient_profile_id()
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select patient_profiles.id
  from accounts.patient_profiles
  join accounts.profiles on profiles.id = patient_profiles.profile_id
  where profiles.user_id = auth.uid()
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION accounts.current_profile_id()
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select id
  from accounts.profiles
  where user_id = auth.uid()
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION accounts.current_pt_profile_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT pt.id
  FROM accounts.pt_profiles pt
  JOIN accounts.profiles p ON p.id = pt.profile_id
  WHERE p.user_id = auth.uid()
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION accounts."current_role"()
 RETURNS accounts.user_role
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select role
  from accounts.profiles
  where user_id = auth.uid()
  limit 1;
$function$
;

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

CREATE OR REPLACE FUNCTION accounts.is_admin()
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select coalesce(accounts.current_role() = 'admin', false);
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_current_user_pt()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.profiles
    WHERE user_id = auth.uid()
    AND role = 'pt'
  );
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_patient()
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select coalesce(accounts.current_role() = 'patient', false);
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_patient_associated_with(pt_profile uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select exists (
    select 1
    from accounts.pt_patient_map map
    where map.patient_profile_id = accounts.current_patient_profile_id()
      and map.pt_profile_id = pt_profile
      and map.status = 'active'
  );
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_patient_mapped_to_current_pt(patient_profile_id_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map ptm
    INNER JOIN accounts.pt_profiles pp ON ptm.pt_profile_id = pp.id
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE ptm.patient_profile_id = patient_profile_id_uuid
      AND p.user_id = auth.uid()
  );
$function$
;

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

CREATE OR REPLACE FUNCTION accounts.is_pt()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM accounts.profiles p
    WHERE p.user_id = auth.uid() AND p.role = 'pt'
  );
$function$
;

CREATE OR REPLACE FUNCTION accounts.is_pt_assigned_to(patient_profile uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  select exists (
    select 1
    from accounts.pt_patient_map map
    where map.patient_profile_id = patient_profile
      and map.pt_profile_id = accounts.current_pt_profile_id()
      and map.status = 'active'
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

CREATE OR REPLACE FUNCTION accounts.is_pt_owner_of(patient_profile uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM accounts.pt_patient_map m
    JOIN accounts.pt_profiles pt ON pt.id = m.pt_profile_id
    JOIN accounts.profiles p     ON p.id  = pt.profile_id
    WHERE m.patient_profile_id = patient_profile
      AND p.user_id = auth.uid()
  );
$function$
;

CREATE OR REPLACE FUNCTION accounts.link_patient_to_current_pt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'accounts', 'public'
AS $function$
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
  v_error_detail text;
BEGIN
  -- Step 1: Get user ID
  BEGIN
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
      RAISE EXCEPTION 'Step 1 failed: No authenticated user found. This function must be called via PostgREST with an authenticated session.';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 1 error: %', SQLERRM;
  END;
  
  -- Step 2: Get patient profile
  BEGIN
    SELECT pp.id INTO v_patient_profile_id
    FROM accounts.patient_profiles pp
    INNER JOIN accounts.profiles p ON pp.profile_id = p.id
    WHERE p.user_id = v_current_user_id
    LIMIT 1;
    
    IF v_patient_profile_id IS NULL THEN
      RAISE EXCEPTION 'Step 2 failed: No patient profile found for user_id: %', v_current_user_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 2 error: %', SQLERRM;
  END;
  
  -- Step 3: Get or create device
  BEGIN
    SELECT id INTO v_device_id
    FROM telemetry.devices
    WHERE hardware_serial = p_bluetooth_identifier
    LIMIT 1;
    
    IF v_device_id IS NULL THEN
      INSERT INTO telemetry.devices (
        hardware_serial,
        status
      ) VALUES (
        p_bluetooth_identifier,
        'unpaired'::telemetry.device_status
      ) RETURNING id INTO v_device_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 3 error (device get/create): %', SQLERRM;
  END;
  
  -- Step 4: Get PT profile ID
  BEGIN
    SELECT ptm.pt_profile_id INTO v_pt_profile_id
    FROM accounts.pt_patient_map ptm
    WHERE ptm.patient_profile_id = v_patient_profile_id
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    -- PT profile ID can be NULL, so we'll just log and continue
    v_pt_profile_id := NULL;
  END;
  
  -- Step 5: Check if assignment exists
  BEGIN
    SELECT id INTO v_device_assignment_id
    FROM telemetry.device_assignments
    WHERE device_id = v_device_id
      AND patient_profile_id = v_patient_profile_id
      AND is_active = true
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Step 5 error (check existing assignment): %', SQLERRM;
  END;
  
  -- Step 6: Insert device assignment (THIS IS WHERE IT'S FAILING)
  IF v_device_assignment_id IS NULL THEN
    BEGIN
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
      
      IF v_device_assignment_id IS NULL THEN
        RAISE EXCEPTION 'Step 6 failed: INSERT succeeded but returned NULL ID';
      END IF;
    EXCEPTION 
      WHEN insufficient_privilege THEN
        RAISE EXCEPTION 'Step 6 error (INSERT permission denied): Current user: %, Has INSERT: %, RLS enabled: %', 
          current_user, 
          has_table_privilege(current_user, 'telemetry.device_assignments', 'INSERT'),
          (SELECT rowsecurity FROM pg_tables WHERE schemaname = 'telemetry' AND tablename = 'device_assignments');
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Step 6 error (INSERT failed): % (SQLSTATE: %). Current user: %, Device ID: %, Patient Profile ID: %, PT Profile ID: %', 
          SQLERRM, SQLSTATE, current_user, v_device_id, v_patient_profile_id, v_pt_profile_id;
    END;
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

CREATE OR REPLACE FUNCTION public.test_current_user()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN current_user::text;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.test_device_assignment_insert(p_bluetooth_identifier text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'telemetry', 'accounts', 'public'
AS $function$
DECLARE
  v_device_id uuid;
  v_patient_profile_id uuid;
  v_current_user_id uuid;
  v_current_user_text text;
  v_is_patient boolean;
  v_current_patient_id uuid;
  v_debug_info jsonb;
BEGIN
  -- Collect debug info
  v_current_user_text := current_user::text;
  v_current_user_id := auth.uid();
  
  -- Get patient profile ID
  SELECT pp.id INTO v_patient_profile_id
  FROM accounts.patient_profiles pp
  INNER JOIN accounts.profiles p ON pp.profile_id = p.id
  WHERE p.user_id = v_current_user_id
  LIMIT 1;
  
  -- Get device ID (or create one)
  SELECT id INTO v_device_id
  FROM telemetry.devices
  WHERE hardware_serial = p_bluetooth_identifier
  LIMIT 1;
  
  IF v_device_id IS NULL THEN
    INSERT INTO telemetry.devices (hardware_serial, status)
    VALUES (p_bluetooth_identifier, 'unpaired'::telemetry.device_status)
    RETURNING id INTO v_device_id;
  END IF;
  
  -- Check if we're a patient
  SELECT accounts.is_patient() INTO v_is_patient;
  SELECT accounts.current_patient_profile_id() INTO v_current_patient_id;
  
  -- Try to insert device assignment and catch any errors
  BEGIN
    INSERT INTO telemetry.device_assignments (
      device_id,
      patient_profile_id,
      pt_profile_id,
      is_active
    ) VALUES (
      v_device_id,
      v_patient_profile_id,
      NULL,
      true
    );
    
    v_debug_info := jsonb_build_object(
      'success', true,
      'current_user', v_current_user_text,
      'auth_uid', v_current_user_id,
      'is_patient', v_is_patient,
      'current_patient_id', v_current_patient_id,
      'patient_profile_id', v_patient_profile_id,
      'device_id', v_device_id,
      'message', 'Insert succeeded'
    );
    
  EXCEPTION WHEN OTHERS THEN
    v_debug_info := jsonb_build_object(
      'success', false,
      'current_user', v_current_user_text,
      'auth_uid', v_current_user_id,
      'is_patient', v_is_patient,
      'current_patient_id', v_current_patient_id,
      'patient_profile_id', v_patient_profile_id,
      'device_id', v_device_id,
      'error', SQLERRM,
      'sqlstate', SQLSTATE
    );
  END;
  
  RETURN v_debug_info;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

grant insert on table "accounts"."patient_profiles" to "authenticated";

grant select on table "accounts"."patient_profiles" to "authenticated";

grant update on table "accounts"."patient_profiles" to "authenticated";

grant insert on table "accounts"."profiles" to "authenticated";

grant select on table "accounts"."profiles" to "authenticated";

grant update on table "accounts"."profiles" to "authenticated";

grant insert on table "accounts"."pt_patient_map" to "authenticated";

grant select on table "accounts"."pt_patient_map" to "authenticated";

grant update on table "accounts"."pt_patient_map" to "authenticated";

grant insert on table "accounts"."pt_profiles" to "authenticated";

grant select on table "accounts"."pt_profiles" to "authenticated";

grant update on table "accounts"."pt_profiles" to "authenticated";

grant delete on table "accounts"."rehab_plans" to "authenticated";

grant insert on table "accounts"."rehab_plans" to "authenticated";

grant select on table "accounts"."rehab_plans" to "authenticated";

grant update on table "accounts"."rehab_plans" to "authenticated";

grant insert on table "telemetry"."calibrations" to "authenticated";

grant select on table "telemetry"."calibrations" to "authenticated";

grant update on table "telemetry"."calibrations" to "authenticated";

grant insert on table "telemetry"."device_assignments" to "authenticated";

grant select on table "telemetry"."device_assignments" to "authenticated";

grant update on table "telemetry"."device_assignments" to "authenticated";

grant insert on table "telemetry"."devices" to "authenticated";

grant select on table "telemetry"."devices" to "authenticated";

grant update on table "telemetry"."devices" to "authenticated";


  create policy "admin_profiles_access"
  on "accounts"."admin_profiles"
  as permissive
  for all
  to public
using (accounts.is_admin())
with check (accounts.is_admin());



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
  WHERE (profiles.user_id = auth.uid()))) OR (profile_id IS NULL) OR accounts.is_patient_mapped_to_current_pt(id)));



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



  create policy "profiles_insert_self"
  on "accounts"."profiles"
  as permissive
  for insert
  to public
with check ((user_id = auth.uid()));



  create policy "profiles_select_owner_or_pt_mapped"
  on "accounts"."profiles"
  as permissive
  for select
  to authenticated
using (((user_id = auth.uid()) OR accounts.is_pt_mapped_to_patient_profile(id)));



  create policy "profiles_select_self"
  on "accounts"."profiles"
  as permissive
  for select
  to public
using ((user_id = auth.uid()));



  create policy "profiles_update_self"
  on "accounts"."profiles"
  as permissive
  for update
  to public
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));



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



  create policy "pt_profiles_insert_owner"
  on "accounts"."pt_profiles"
  as permissive
  for insert
  to authenticated
with check ((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))));



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



  create policy "pt_profiles_update_owner"
  on "accounts"."pt_profiles"
  as permissive
  for update
  to authenticated
using ((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))))
with check ((profile_id IN ( SELECT profiles.id
   FROM accounts.profiles
  WHERE (profiles.user_id = auth.uid()))));



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



  create policy "assets_access"
  on "content"."assets"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (uploader_profile_id = accounts.current_profile_id()) OR (accounts.is_pt() AND (EXISTS ( SELECT 1
   FROM (rehab.sessions s
     JOIN rehab.plan_assignments pa ON ((pa.id = s.plan_assignment_id)))
  WHERE ((s.id = assets.linked_session_id) AND (pa.pt_profile_id = accounts.current_pt_profile_id()))))) OR (accounts.is_patient() AND (EXISTS ( SELECT 1
   FROM (rehab.sessions s
     JOIN rehab.plan_assignments pa ON ((pa.id = s.plan_assignment_id)))
  WHERE ((s.id = assets.linked_session_id) AND (pa.patient_profile_id = accounts.current_patient_profile_id())))))))
with check ((accounts.is_admin() OR (uploader_profile_id = accounts.current_profile_id())));



  create policy "lesson_assets_access"
  on "content"."lesson_assets"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM (rehab.plan_lessons pl
     JOIN rehab.plans p ON ((p.id = pl.plan_id)))
  WHERE ((pl.id = lesson_assets.plan_lesson_id) AND ((accounts.is_pt() AND (p.created_by_pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (EXISTS ( SELECT 1
           FROM rehab.plan_assignments pa
          WHERE ((pa.plan_id = pl.plan_id) AND (pa.patient_profile_id = accounts.current_patient_profile_id())))))))))))
with check ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM (rehab.plan_lessons pl
     JOIN rehab.plans p ON ((p.id = pl.plan_id)))
  WHERE ((pl.id = lesson_assets.plan_lesson_id) AND ((accounts.is_pt() AND (p.created_by_pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (EXISTS ( SELECT 1
           FROM rehab.plan_assignments pa
          WHERE ((pa.plan_id = pl.plan_id) AND (pa.patient_profile_id = accounts.current_patient_profile_id())))))))))));



  create policy "exercises_read_all"
  on "rehab"."exercises"
  as permissive
  for select
  to public
using ((auth.uid() IS NOT NULL));



  create policy "lesson_progress_access"
  on "rehab"."lesson_progress"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.id = lesson_progress.plan_assignment_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))))
with check ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.id = lesson_progress.plan_assignment_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))));



  create policy "plan_assignments_manage_pt"
  on "rehab"."plan_assignments"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = pt_profile_id))))
with check ((accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = pt_profile_id))));



  create policy "plan_assignments_select_accessible"
  on "rehab"."plan_assignments"
  as permissive
  for select
  to public
using ((accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = pt_profile_id)) OR (accounts.is_patient() AND (accounts.current_patient_profile_id() = patient_profile_id))));



  create policy "plan_lessons_access"
  on "rehab"."plan_lessons"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (accounts.is_pt() AND (EXISTS ( SELECT 1
   FROM rehab.plans
  WHERE ((plans.id = plan_lessons.plan_id) AND (plans.created_by_pt_profile_id = accounts.current_pt_profile_id()))))) OR (accounts.is_patient() AND (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.plan_id = plan_lessons.plan_id) AND (pa.patient_profile_id = accounts.current_patient_profile_id())))))))
with check ((accounts.is_admin() OR (accounts.is_pt() AND (EXISTS ( SELECT 1
   FROM rehab.plans
  WHERE ((plans.id = plan_lessons.plan_id) AND (plans.created_by_pt_profile_id = accounts.current_pt_profile_id())))))));



  create policy "schedule_slots_access"
  on "rehab"."plan_schedule_slots"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.id = plan_schedule_slots.plan_assignment_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))))
with check ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.id = plan_schedule_slots.plan_assignment_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))));



  create policy "plans_manage_owner"
  on "rehab"."plans"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = created_by_pt_profile_id))))
with check ((accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = created_by_pt_profile_id))));



  create policy "plans_select_accessible"
  on "rehab"."plans"
  as permissive
  for select
  to public
using ((accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = created_by_pt_profile_id)) OR (accounts.is_patient() AND (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.plan_id = plans.id) AND (pa.patient_profile_id = accounts.current_patient_profile_id())))))));



  create policy "session_metrics_access"
  on "rehab"."session_metrics"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM (rehab.sessions s
     JOIN rehab.plan_assignments pa ON ((pa.id = s.plan_assignment_id)))
  WHERE ((s.id = session_metrics.session_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))))
with check ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM (rehab.sessions s
     JOIN rehab.plan_assignments pa ON ((pa.id = s.plan_assignment_id)))
  WHERE ((s.id = session_metrics.session_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))));



  create policy "sessions_access"
  on "rehab"."sessions"
  as permissive
  for all
  to public
using ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.id = sessions.plan_assignment_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))))
with check ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM rehab.plan_assignments pa
  WHERE ((pa.id = sessions.plan_assignment_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))));



  create policy "calibrations_access"
  on "telemetry"."calibrations"
  as permissive
  for all
  to public
using (((CURRENT_USER = 'postgres'::name) OR accounts.is_admin() OR (accounts.is_pt() AND (EXISTS ( SELECT 1
   FROM telemetry.device_assignments da
  WHERE ((da.id = calibrations.device_assignment_id) AND (da.pt_profile_id = accounts.current_pt_profile_id()))))) OR (accounts.is_patient() AND (EXISTS ( SELECT 1
   FROM telemetry.device_assignments da
  WHERE ((da.id = calibrations.device_assignment_id) AND (da.patient_profile_id = accounts.current_patient_profile_id())))))))
with check (((CURRENT_USER = 'postgres'::name) OR accounts.is_admin() OR (accounts.is_patient() AND (EXISTS ( SELECT 1
   FROM telemetry.device_assignments da
  WHERE ((da.id = calibrations.device_assignment_id) AND (da.patient_profile_id = accounts.current_patient_profile_id()))))) OR (accounts.is_pt() AND (EXISTS ( SELECT 1
   FROM telemetry.device_assignments da
  WHERE ((da.id = calibrations.device_assignment_id) AND (da.pt_profile_id = accounts.current_pt_profile_id())))))));



  create policy "device_assignments_access"
  on "telemetry"."device_assignments"
  as permissive
  for all
  to public
using (((CURRENT_USER = 'postgres'::name) OR accounts.is_admin() OR (accounts.is_pt() AND (accounts.current_pt_profile_id() = pt_profile_id)) OR (accounts.is_patient() AND (accounts.current_patient_profile_id() = patient_profile_id)) OR (current_setting('request.jwt.claim.role'::text, true) = 'authenticated'::text)))
with check (((CURRENT_USER = 'postgres'::name) OR accounts.is_admin() OR (accounts.is_patient() AND (accounts.current_patient_profile_id() = patient_profile_id)) OR (current_setting('request.jwt.claim.role'::text, true) = 'authenticated'::text) OR (accounts.is_pt() AND ((accounts.current_pt_profile_id() = pt_profile_id) OR (pt_profile_id IS NULL)))));



  create policy "devices_manage_admin"
  on "telemetry"."devices"
  as permissive
  for all
  to public
using (accounts.is_admin())
with check (accounts.is_admin());



  create policy "devices_read"
  on "telemetry"."devices"
  as permissive
  for select
  to public
using ((accounts.is_admin() OR accounts.is_pt()));



  create policy "session_samples_access"
  on "telemetry"."session_samples"
  as permissive
  for select
  to public
using ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM (rehab.sessions s
     JOIN rehab.plan_assignments pa ON ((pa.id = s.plan_assignment_id)))
  WHERE ((s.id = session_samples.session_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))));



  create policy "session_samples_insert_by_device_owner"
  on "telemetry"."session_samples"
  as permissive
  for insert
  to public
with check ((accounts.is_admin() OR (EXISTS ( SELECT 1
   FROM (rehab.sessions s
     JOIN rehab.plan_assignments pa ON ((pa.id = s.plan_assignment_id)))
  WHERE ((s.id = session_samples.session_id) AND ((accounts.is_pt() AND (pa.pt_profile_id = accounts.current_pt_profile_id())) OR (accounts.is_patient() AND (pa.patient_profile_id = accounts.current_patient_profile_id()))))))));


CREATE TRIGGER trg_admin_profiles_updated_at BEFORE UPDATE ON accounts.admin_profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_link_patient_to_pt AFTER INSERT ON accounts.patient_profiles FOR EACH ROW EXECUTE FUNCTION accounts.link_patient_to_current_pt();

CREATE TRIGGER trg_patient_profiles_updated_at BEFORE UPDATE ON accounts.patient_profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON accounts.profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_pt_patient_map_updated_at BEFORE UPDATE ON accounts.pt_patient_map FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_pt_profiles_updated_at BEFORE UPDATE ON accounts.pt_profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_assets_updated_at BEFORE UPDATE ON content.assets FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_exercises_updated_at BEFORE UPDATE ON rehab.exercises FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_lesson_progress_updated_at BEFORE UPDATE ON rehab.lesson_progress FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_plan_assignments_updated_at BEFORE UPDATE ON rehab.plan_assignments FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_plan_lessons_updated_at BEFORE UPDATE ON rehab.plan_lessons FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_plans_updated_at BEFORE UPDATE ON rehab.plans FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_session_metrics_updated_at BEFORE UPDATE ON rehab.session_metrics FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_sessions_updated_at BEFORE UPDATE ON rehab.sessions FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_device_assignments_updated_at BEFORE UPDATE ON telemetry.device_assignments FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_devices_updated_at BEFORE UPDATE ON telemetry.devices FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


