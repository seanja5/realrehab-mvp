-- ====================================================================
-- Real Rehab Supabase Schema
-- Generated to align with the SwiftUI client, .cursor documentation,
-- and project chatdoc summary. Paste directly into the Supabase SQL
-- editor to provision a production-ready database.
-- ====================================================================

-- Ensure pgcrypto is available for gen_random_uuid()
create extension if not exists "pgcrypto";
create extension if not exists "citext";

-- Set a predictable search path for this migration.
set search_path = public;

-- --------------------------------------------------------------------
-- Global helper function for updated_at columns
-- --------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- --------------------------------------------------------------------
-- Create domain schemas
-- --------------------------------------------------------------------
create schema if not exists accounts;
create schema if not exists rehab;
create schema if not exists telemetry;
create schema if not exists content;

-- --------------------------------------------------------------------
-- Enumerations
-- --------------------------------------------------------------------
-- Accounts / identity
create type accounts.user_role as enum ('patient', 'pt', 'admin');
create type accounts.gender as enum (
  'female',
  'male',
  'non_binary',
  'prefer_not_to_say',
  'other'
);
create type accounts.assignment_status as enum ('pending', 'active', 'suspended', 'archived');

-- Rehab domain
create type rehab.plan_status as enum ('draft', 'active', 'suspended', 'completed', 'archived');
create type rehab.session_status as enum ('scheduled', 'in_progress', 'completed', 'aborted');
create type rehab.lesson_phase as enum ('phase_1', 'phase_2', 'phase_3', 'phase_4');
create type rehab.exercise_difficulty as enum ('beginner', 'intermediate', 'advanced');

-- Telemetry domain
create type telemetry.device_status as enum ('unpaired', 'paired', 'maintenance', 'retired');
create type telemetry.calibration_stage as enum ('starting_position', 'maximum_position', 'full_range');

-- Content domain
create type content.asset_status as enum ('pending', 'available', 'processing', 'failed');
create type content.asset_purpose as enum ('session_upload', 'lesson_reference', 'plan_resource');

-- ====================================================================
-- ACCOUNTS SCHEMA
-- ====================================================================

-- --------------------------------------------------------------------
-- Base profile tying auth.users to domain roles
-- --------------------------------------------------------------------
create table if not exists accounts.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  role accounts.user_role not null,
  email citext not null unique,
  first_name text not null,
  last_name text not null,
  phone text,
  timezone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_profiles_updated_at
before update on accounts.profiles
for each row
execute function public.touch_updated_at();

create index if not exists idx_profiles_role on accounts.profiles(role);

-- --------------------------------------------------------------------
-- Patient profile details captured during onboarding
-- --------------------------------------------------------------------
create table if not exists accounts.patient_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references accounts.profiles(id) on delete cascade,
  date_of_birth date,
  gender accounts.gender,
  surgery_date date,
  last_pt_visit date,
  allow_notifications boolean not null default true,
  allow_camera boolean not null default true,
  intake_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_patient_profiles_updated_at
before update on accounts.patient_profiles
for each row
execute function public.touch_updated_at();

-- --------------------------------------------------------------------
-- Physical therapist profile details
-- --------------------------------------------------------------------
create table if not exists accounts.pt_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references accounts.profiles(id) on delete cascade,
  practice_name text,
  license_number text,
  npi_number text,
  contact_email citext,
  contact_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_pt_profiles_updated_at
before update on accounts.pt_profiles
for each row
execute function public.touch_updated_at();

-- --------------------------------------------------------------------
-- Optional admin profile metadata
-- --------------------------------------------------------------------
create table if not exists accounts.admin_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references accounts.profiles(id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_admin_profiles_updated_at
before update on accounts.admin_profiles
for each row
execute function public.touch_updated_at();

-- --------------------------------------------------------------------
-- PT ↔ Patient relationship map (assignment lifecycle)
-- --------------------------------------------------------------------
create table if not exists accounts.pt_patient_map (
  id uuid primary key default gen_random_uuid(),
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  pt_profile_id uuid not null references accounts.pt_profiles(id) on delete cascade,
  status accounts.assignment_status not null default 'pending',
  assigned_at timestamptz not null default now(),
  accepted_at timestamptz,
  archived_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (patient_profile_id, pt_profile_id)
);

create trigger trg_pt_patient_map_updated_at
before update on accounts.pt_patient_map
for each row
execute function public.touch_updated_at();

create index if not exists idx_pt_patient_map_patient on accounts.pt_patient_map(patient_profile_id);
create index if not exists idx_pt_patient_map_pt on accounts.pt_patient_map(pt_profile_id);
create index if not exists idx_pt_patient_map_status on accounts.pt_patient_map(status);

-- --------------------------------------------------------------------
-- Helper security-definer functions for RLS
-- --------------------------------------------------------------------
create or replace function accounts.current_profile_id()
returns uuid
language sql
security definer
set search_path = accounts, public
as $$
  select id
  from accounts.profiles
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function accounts.current_role()
returns accounts.user_role
language sql
security definer
set search_path = accounts, public
as $$
  select role
  from accounts.profiles
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function accounts.is_admin()
returns boolean
language sql
security definer
set search_path = accounts, public
as $$
  select coalesce(accounts.current_role() = 'admin', false);
$$;

create or replace function accounts.is_pt()
returns boolean
language sql
security definer
set search_path = accounts, public
as $$
  select coalesce(accounts.current_role() = 'pt', false);
$$;

create or replace function accounts.is_patient()
returns boolean
language sql
security definer
set search_path = accounts, public
as $$
  select coalesce(accounts.current_role() = 'patient', false);
$$;

create or replace function accounts.current_patient_profile_id()
returns uuid
language sql
security definer
set search_path = accounts, public
as $$
  select patient_profiles.id
  from accounts.patient_profiles
  join accounts.profiles on profiles.id = patient_profiles.profile_id
  where profiles.user_id = auth.uid()
  limit 1;
$$;

create or replace function accounts.current_pt_profile_id()
returns uuid
language sql
security definer
set search_path = accounts, public
as $$
  select pt_profiles.id
  from accounts.pt_profiles
  join accounts.profiles on profiles.id = pt_profiles.profile_id
  where profiles.user_id = auth.uid()
  limit 1;
$$;

-- Helper to check whether the acting PT is assigned to the given patient profile.
create or replace function accounts.is_pt_assigned_to(patient_profile uuid)
returns boolean
language sql
security definer
set search_path = accounts, public
as $$
  select exists (
    select 1
    from accounts.pt_patient_map map
    where map.patient_profile_id = patient_profile
      and map.pt_profile_id = accounts.current_pt_profile_id()
      and map.status = 'active'
  );
$$;

-- Helper to check whether the acting patient is linked to a PT profile.
create or replace function accounts.is_patient_associated_with(pt_profile uuid)
returns boolean
language sql
security definer
set search_path = accounts, public
as $$
  select exists (
    select 1
    from accounts.pt_patient_map map
    where map.patient_profile_id = accounts.current_patient_profile_id()
      and map.pt_profile_id = pt_profile
      and map.status = 'active'
  );
$$;

-- --------------------------------------------------------------------
-- Row Level Security Policies for accounts schema
-- --------------------------------------------------------------------
alter table accounts.profiles enable row level security;
alter table accounts.patient_profiles enable row level security;
alter table accounts.pt_profiles enable row level security;
alter table accounts.admin_profiles enable row level security;
alter table accounts.pt_patient_map enable row level security;

-- Profiles policies
create policy profiles_select_self_or_assignment
  on accounts.profiles
  for select
  using (
    auth.uid() = user_id
    or accounts.is_admin()
    or (
      accounts.is_pt()
      and exists (
        select 1
        from accounts.patient_profiles patient
        join accounts.pt_patient_map map on map.patient_profile_id = patient.id
        where patient.profile_id = accounts.profiles.id
          and map.pt_profile_id = accounts.current_pt_profile_id()
          and map.status = 'active'
      )
    )
    or (
      accounts.is_patient()
      and exists (
        select 1
        from accounts.pt_profiles pt
        join accounts.pt_patient_map map on map.pt_profile_id = pt.id
        where pt.profile_id = accounts.profiles.id
          and map.patient_profile_id = accounts.current_patient_profile_id()
          and map.status = 'active'
      )
    )
  );

create policy profiles_update_self
  on accounts.profiles
  for update
  using (auth.uid() = user_id or accounts.is_admin())
  with check (auth.uid() = user_id or accounts.is_admin());

create policy profiles_insert_self
  on accounts.profiles
  for insert
  with check (auth.uid() = user_id or accounts.is_admin());

-- Patient profile policies
create policy patient_profiles_select
  on accounts.patient_profiles
  for select
  using (
    accounts.is_admin()
    or (accounts.is_patient() and accounts.current_patient_profile_id() = accounts.patient_profiles.id)
    or (accounts.is_pt() and accounts.is_pt_assigned_to(accounts.patient_profiles.id))
  );

create policy patient_profiles_mutate_self
  on accounts.patient_profiles
  for all
  using (
    accounts.is_admin()
    or (accounts.is_patient() and accounts.current_patient_profile_id() = accounts.patient_profiles.id)
  )
  with check (
    accounts.is_admin()
    or (accounts.is_patient() and accounts.current_patient_profile_id() = accounts.patient_profiles.id)
  );

-- PT profile policies
create policy pt_profiles_select
  on accounts.pt_profiles
  for select
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = accounts.pt_profiles.id)
    or (accounts.is_patient() and accounts.is_patient_associated_with(accounts.pt_profiles.id))
  );

create policy pt_profiles_mutate_self
  on accounts.pt_profiles
  for all
  using (accounts.is_admin() or (accounts.is_pt() and accounts.current_pt_profile_id() = accounts.pt_profiles.id))
  with check (accounts.is_admin() or (accounts.is_pt() and accounts.current_pt_profile_id() = accounts.pt_profiles.id));

-- Admin profile policies (admin-only)
create policy admin_profiles_access
  on accounts.admin_profiles
  for all
  using (accounts.is_admin())
  with check (accounts.is_admin());

-- PT ↔ patient map policies
create policy pt_patient_map_select
  on accounts.pt_patient_map
  for select
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = accounts.pt_patient_map.pt_profile_id)
    or (accounts.is_patient() and accounts.current_patient_profile_id() = accounts.pt_patient_map.patient_profile_id)
  );

create policy pt_patient_map_manage_by_pt
  on accounts.pt_patient_map
  for all
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = accounts.pt_patient_map.pt_profile_id)
  )
  with check (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = accounts.pt_patient_map.pt_profile_id)
  );

-- ====================================================================
-- REHAB SCHEMA
-- ====================================================================

-- --------------------------------------------------------------------
-- Master list of exercises
-- --------------------------------------------------------------------
create table if not exists rehab.exercises (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  display_name text not null,
  description text,
  body_region text,
  difficulty rehab.exercise_difficulty not null default 'beginner',
  default_reps integer,
  default_rest_seconds integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_exercises_updated_at
before update on rehab.exercises
for each row
execute function public.touch_updated_at();

-- Seed baseline exercises aligned with current Swift UI
insert into rehab.exercises (slug, display_name, description, body_region, difficulty, default_reps, default_rest_seconds)
values
  ('knee_extension', 'Knee Extension', 'Foundational knee extension exercise for ACL rehab.', 'lower_extremity', 'beginner', 20, 3),
  ('wall_sit', 'Wall Sit', 'Isometric wall sit hold for quad activation.', 'lower_extremity', 'intermediate', 12, 3),
  ('lunge', 'Forward Lunge', 'Alternating lunges focusing on stability and range.', 'lower_extremity', 'intermediate', 12, 3)
on conflict (slug) do nothing;

-- --------------------------------------------------------------------
-- Rehab plans configured by PTs for patients
-- --------------------------------------------------------------------
create table if not exists rehab.plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  injury_focus text not null default 'ACL Tear Recovery',
  status rehab.plan_status not null default 'draft',
  created_by_pt_profile_id uuid not null references accounts.pt_profiles(id) on delete restrict,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_plans_updated_at
before update on rehab.plans
for each row
execute function public.touch_updated_at();

create index if not exists idx_plans_status on rehab.plans(status);
create index if not exists idx_plans_created_by_pt on rehab.plans(created_by_pt_profile_id);

-- --------------------------------------------------------------------
-- Patient-specific plan assignment metadata
-- --------------------------------------------------------------------
create table if not exists rehab.plan_assignments (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references rehab.plans(id) on delete cascade,
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  pt_profile_id uuid not null references accounts.pt_profiles(id) on delete cascade,
  started_on date,
  completed_on date,
  allow_reminders boolean not null default true,
  allow_camera boolean not null default true,
  timezone text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, patient_profile_id)
);

create trigger trg_plan_assignments_updated_at
before update on rehab.plan_assignments
for each row
execute function public.touch_updated_at();

create index if not exists idx_plan_assignments_patient on rehab.plan_assignments(patient_profile_id);
create index if not exists idx_plan_assignments_pt on rehab.plan_assignments(pt_profile_id);

-- --------------------------------------------------------------------
-- Weekly schedule selections (day-of-week + time slots)
-- --------------------------------------------------------------------
create table if not exists rehab.plan_schedule_slots (
  id uuid primary key default gen_random_uuid(),
  plan_assignment_id uuid not null references rehab.plan_assignments(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  slot_time time not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_plan_schedule_slots_assignment on rehab.plan_schedule_slots(plan_assignment_id);
create index if not exists idx_plan_schedule_slots_day on rehab.plan_schedule_slots(day_of_week);

-- --------------------------------------------------------------------
-- Lessons configured within a plan (mirrors JourneyMap & PT editor)
-- --------------------------------------------------------------------
create table if not exists rehab.plan_lessons (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references rehab.plans(id) on delete cascade,
  exercise_id uuid references rehab.exercises(id) on delete set null,
  phase rehab.lesson_phase not null default 'phase_1',
  title text,
  icon_name text,
  is_locked boolean not null default false,
  reps integer,
  rest_seconds integer,
  sequence_position integer not null,
  video_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, sequence_position)
);

create trigger trg_plan_lessons_updated_at
before update on rehab.plan_lessons
for each row
execute function public.touch_updated_at();

create index if not exists idx_plan_lessons_plan on rehab.plan_lessons(plan_id);
create index if not exists idx_plan_lessons_exercise on rehab.plan_lessons(exercise_id);

-- --------------------------------------------------------------------
-- Progress per patient for each lesson (unlocked/completed tracking)
-- --------------------------------------------------------------------
create table if not exists rehab.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  plan_assignment_id uuid not null references rehab.plan_assignments(id) on delete cascade,
  plan_lesson_id uuid not null references rehab.plan_lessons(id) on delete cascade,
  unlocked_at timestamptz,
  completed_at timestamptz,
  last_session_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_assignment_id, plan_lesson_id)
);

create trigger trg_lesson_progress_updated_at
before update on rehab.lesson_progress
for each row
execute function public.touch_updated_at();

-- --------------------------------------------------------------------
-- Individual rehab sessions launched from the LessonView
-- --------------------------------------------------------------------
create table if not exists rehab.sessions (
  id uuid primary key default gen_random_uuid(),
  plan_assignment_id uuid not null references rehab.plan_assignments(id) on delete cascade,
  plan_lesson_id uuid not null references rehab.plan_lessons(id) on delete cascade,
  status rehab.session_status not null default 'scheduled',
  scheduled_for timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  expected_reps integer,
  expected_rest_seconds integer,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_sessions_updated_at
before update on rehab.sessions
for each row
execute function public.touch_updated_at();

create index if not exists idx_sessions_assignment on rehab.sessions(plan_assignment_id);
create index if not exists idx_sessions_lesson on rehab.sessions(plan_lesson_id);
create index if not exists idx_sessions_status on rehab.sessions(status);

-- --------------------------------------------------------------------
-- Aggregated session metrics (mirrors CompletionView summary)
-- --------------------------------------------------------------------
create table if not exists rehab.session_metrics (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references rehab.sessions(id) on delete cascade,
  total_reps integer,
  accuracy_percent numeric(5,2),
  range_of_motion_deg numeric(6,2),
  session_duration_seconds integer,
  average_flex_value numeric(8,4),
  peak_flex_value numeric(8,4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_session_metrics_updated_at
before update on rehab.session_metrics
for each row
execute function public.touch_updated_at();

-- --------------------------------------------------------------------
-- RLS for rehab schema (leveraging accounts helper functions)
-- --------------------------------------------------------------------
alter table rehab.exercises enable row level security;
alter table rehab.plans enable row level security;
alter table rehab.plan_assignments enable row level security;
alter table rehab.plan_schedule_slots enable row level security;
alter table rehab.plan_lessons enable row level security;
alter table rehab.lesson_progress enable row level security;
alter table rehab.sessions enable row level security;
alter table rehab.session_metrics enable row level security;

-- Exercises are readable by all authenticated users (content is static)
create policy exercises_read_all
  on rehab.exercises
  for select
  using (auth.uid() is not null);

-- Plans
create policy plans_select_accessible
  on rehab.plans
  for select
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = rehab.plans.created_by_pt_profile_id)
    or (
      accounts.is_patient()
      and exists (
        select 1
        from rehab.plan_assignments pa
        where pa.plan_id = rehab.plans.id
          and pa.patient_profile_id = accounts.current_patient_profile_id()
      )
    )
  );

create policy plans_manage_owner
  on rehab.plans
  for all
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = rehab.plans.created_by_pt_profile_id)
  )
  with check (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = rehab.plans.created_by_pt_profile_id)
  );

-- Plan assignments (patient ⟷ PT binding)
create policy plan_assignments_select_accessible
  on rehab.plan_assignments
  for select
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = rehab.plan_assignments.pt_profile_id)
    or (accounts.is_patient() and accounts.current_patient_profile_id() = rehab.plan_assignments.patient_profile_id)
  );

create policy plan_assignments_manage_pt
  on rehab.plan_assignments
  for all
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = rehab.plan_assignments.pt_profile_id)
  )
  with check (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = rehab.plan_assignments.pt_profile_id)
  );

-- Schedule slots
create policy schedule_slots_access
  on rehab.plan_schedule_slots
  for all
  using (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_assignments pa
      where pa.id = rehab.plan_schedule_slots.plan_assignment_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  )
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_assignments pa
      where pa.id = rehab.plan_schedule_slots.plan_assignment_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

-- Plan lessons
create policy plan_lessons_access
  on rehab.plan_lessons
  for all
  using (
    accounts.is_admin()
    or (
      accounts.is_pt()
      and exists (
        select 1
        from rehab.plans
        where plans.id = rehab.plan_lessons.plan_id
          and plans.created_by_pt_profile_id = accounts.current_pt_profile_id()
      )
    )
    or (
      accounts.is_patient()
      and exists (
        select 1
        from rehab.plan_assignments pa
        where pa.plan_id = rehab.plan_lessons.plan_id
          and pa.patient_profile_id = accounts.current_patient_profile_id()
      )
    )
  )
  with check (
    accounts.is_admin()
    or (
      accounts.is_pt()
      and exists (
        select 1
        from rehab.plans
        where plans.id = rehab.plan_lessons.plan_id
          and plans.created_by_pt_profile_id = accounts.current_pt_profile_id()
      )
    )
  );

-- Lesson progress
create policy lesson_progress_access
  on rehab.lesson_progress
  for all
  using (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_assignments pa
      where pa.id = rehab.lesson_progress.plan_assignment_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  )
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_assignments pa
      where pa.id = rehab.lesson_progress.plan_assignment_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

-- Sessions & metrics
create policy sessions_access
  on rehab.sessions
  for all
  using (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_assignments pa
      where pa.id = rehab.sessions.plan_assignment_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  )
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_assignments pa
      where pa.id = rehab.sessions.plan_assignment_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

create policy session_metrics_access
  on rehab.session_metrics
  for all
  using (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.sessions s
      join rehab.plan_assignments pa on pa.id = s.plan_assignment_id
      where s.id = rehab.session_metrics.session_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  )
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.sessions s
      join rehab.plan_assignments pa on pa.id = s.plan_assignment_id
      where s.id = rehab.session_metrics.session_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

-- ====================================================================
-- TELEMETRY SCHEMA
-- ====================================================================

-- --------------------------------------------------------------------
-- Physical sensor devices paired to patients
-- --------------------------------------------------------------------
create table if not exists telemetry.devices (
  id uuid primary key default gen_random_uuid(),
  hardware_serial text not null unique,
  firmware_version text,
  status telemetry.device_status not null default 'unpaired',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_devices_updated_at
before update on telemetry.devices
for each row
execute function public.touch_updated_at();

-- --------------------------------------------------------------------
-- Device assignment lifecycle (patient + PT oversight)
-- --------------------------------------------------------------------
create table if not exists telemetry.device_assignments (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references telemetry.devices(id) on delete cascade,
  patient_profile_id uuid not null references accounts.patient_profiles(id) on delete cascade,
  pt_profile_id uuid references accounts.pt_profiles(id),
  paired_at timestamptz not null default now(),
  unpaired_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_device_assignments_updated_at
before update on telemetry.device_assignments
for each row
execute function public.touch_updated_at();

create index if not exists idx_device_assignments_device on telemetry.device_assignments(device_id);
create index if not exists idx_device_assignments_patient on telemetry.device_assignments(patient_profile_id);
create unique index if not exists uniq_device_active_assignment
  on telemetry.device_assignments(device_id)
  where is_active;
create unique index if not exists uniq_device_active_assignment
  on telemetry.device_assignments(device_id)
  where is_active;

-- --------------------------------------------------------------------
-- Calibration events recorded from the CalibrateDeviceView
-- --------------------------------------------------------------------
create table if not exists telemetry.calibrations (
  id uuid primary key default gen_random_uuid(),
  device_assignment_id uuid not null references telemetry.device_assignments(id) on delete cascade,
  stage telemetry.calibration_stage not null,
  recorded_at timestamptz not null default now(),
  flex_value numeric(8,4),
  knee_angle_deg numeric(6,2),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_calibrations_assignment on telemetry.calibrations(device_assignment_id);
create index if not exists idx_calibrations_stage on telemetry.calibrations(stage);

-- --------------------------------------------------------------------
-- Telemetry session samples (Arduino + IMU + flex sensor)
-- --------------------------------------------------------------------
create table if not exists telemetry.session_samples (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references rehab.sessions(id) on delete cascade,
  device_assignment_id uuid references telemetry.device_assignments(id) on delete set null,
  recorded_at timestamptz not null,
  flex_value numeric(10,5),
  knee_angle_deg numeric(6,2),
  quat_w double precision,
  quat_x double precision,
  quat_y double precision,
  quat_z double precision,
  accel_x double precision,
  accel_y double precision,
  accel_z double precision,
  gyro_x double precision,
  gyro_y double precision,
  gyro_z double precision,
  temperature_c double precision,
  created_at timestamptz not null default now()
);

create index if not exists idx_session_samples_session on telemetry.session_samples(session_id);
create index if not exists idx_session_samples_recorded_at on telemetry.session_samples(session_id, recorded_at);

-- --------------------------------------------------------------------
-- RLS policies for telemetry
-- --------------------------------------------------------------------
alter table telemetry.devices enable row level security;
alter table telemetry.device_assignments enable row level security;
alter table telemetry.calibrations enable row level security;
alter table telemetry.session_samples enable row level security;

-- Devices (admin + PT visibility)
create policy devices_read
  on telemetry.devices
  for select
  using (accounts.is_admin() or accounts.is_pt());

create policy devices_manage_admin
  on telemetry.devices
  for all
  using (accounts.is_admin())
  with check (accounts.is_admin());

-- Device assignments
create policy device_assignments_access
  on telemetry.device_assignments
  for all
  using (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    or (accounts.is_patient() and accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  )
  with check (
    accounts.is_admin()
    or (accounts.is_pt() and accounts.current_pt_profile_id() = telemetry.device_assignments.pt_profile_id)
    or (accounts.is_patient() and accounts.current_patient_profile_id() = telemetry.device_assignments.patient_profile_id)
  );

-- Calibrations
create policy calibrations_access
  on telemetry.calibrations
  for all
  using (
    accounts.is_admin()
    or exists (
      select 1
      from telemetry.device_assignments da
      where da.id = telemetry.calibrations.device_assignment_id
        and (
          (accounts.is_pt() and da.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and da.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  )
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from telemetry.device_assignments da
      where da.id = telemetry.calibrations.device_assignment_id
        and (
          (accounts.is_pt() and da.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and da.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

-- Session samples (join-heavy, indexed)
create policy session_samples_access
  on telemetry.session_samples
  for select
  using (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.sessions s
      join rehab.plan_assignments pa on pa.id = s.plan_assignment_id
      where s.id = telemetry.session_samples.session_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

create policy session_samples_insert_by_device_owner
  on telemetry.session_samples
  for insert
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.sessions s
      join rehab.plan_assignments pa on pa.id = s.plan_assignment_id
      where s.id = telemetry.session_samples.session_id
        and (
          (accounts.is_pt() and pa.pt_profile_id = accounts.current_pt_profile_id())
          or (accounts.is_patient() and pa.patient_profile_id = accounts.current_patient_profile_id())
        )
    )
  );

-- ====================================================================
-- CONTENT SCHEMA
-- ====================================================================

-- --------------------------------------------------------------------
-- Media assets (future patient uploads or PT resources)
-- --------------------------------------------------------------------
create table if not exists content.assets (
  id uuid primary key default gen_random_uuid(),
  uploader_profile_id uuid not null references accounts.profiles(id) on delete cascade,
  status content.asset_status not null default 'pending',
  purpose content.asset_purpose not null default 'session_upload',
  storage_path text not null unique,
  file_name text,
  content_type text,
  duration_seconds numeric(8,2),
  file_size_bytes bigint,
  linked_session_id uuid references rehab.sessions(id) on delete set null,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_assets_updated_at
before update on content.assets
for each row
execute function public.touch_updated_at();

create index if not exists idx_assets_uploader on content.assets(uploader_profile_id);
create index if not exists idx_assets_session on content.assets(linked_session_id);

-- --------------------------------------------------------------------
-- Optional mapping of assets to lesson templates (PT curated content)
-- --------------------------------------------------------------------
create table if not exists content.lesson_assets (
  id uuid primary key default gen_random_uuid(),
  plan_lesson_id uuid not null references rehab.plan_lessons(id) on delete cascade,
  asset_id uuid not null references content.assets(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (plan_lesson_id, asset_id)
);

create index if not exists idx_lesson_assets_lesson on content.lesson_assets(plan_lesson_id);

-- --------------------------------------------------------------------
-- RLS for content schema
-- --------------------------------------------------------------------
alter table content.assets enable row level security;
alter table content.lesson_assets enable row level security;

create policy assets_access
  on content.assets
  for all
  using (
    accounts.is_admin()
    or uploader_profile_id = accounts.current_profile_id()
    or (
      accounts.is_pt()
      and exists (
        select 1
        from rehab.sessions s
        join rehab.plan_assignments pa on pa.id = s.plan_assignment_id
        where s.id = content.assets.linked_session_id
          and pa.pt_profile_id = accounts.current_pt_profile_id()
      )
    )
    or (
      accounts.is_patient()
      and exists (
        select 1
        from rehab.sessions s
        join rehab.plan_assignments pa on pa.id = s.plan_assignment_id
        where s.id = content.assets.linked_session_id
          and pa.patient_profile_id = accounts.current_patient_profile_id()
      )
    )
  )
  with check (
    accounts.is_admin()
    or uploader_profile_id = accounts.current_profile_id()
  );

create policy lesson_assets_access
  on content.lesson_assets
  for all
  using (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_lessons pl
      join rehab.plans p on p.id = pl.plan_id
      where pl.id = content.lesson_assets.plan_lesson_id
        and (
          (accounts.is_pt() and p.created_by_pt_profile_id = accounts.current_pt_profile_id())
          or (
            accounts.is_patient()
            and exists (
              select 1
              from rehab.plan_assignments pa
              where pa.plan_id = pl.plan_id
                and pa.patient_profile_id = accounts.current_patient_profile_id()
            )
          )
        )
    )
  )
  with check (
    accounts.is_admin()
    or exists (
      select 1
      from rehab.plan_lessons pl
      join rehab.plans p on p.id = pl.plan_id
      where pl.id = content.lesson_assets.plan_lesson_id
        and (
          (accounts.is_pt() and p.created_by_pt_profile_id = accounts.current_pt_profile_id())
          or (
            accounts.is_patient()
            and exists (
              select 1
              from rehab.plan_assignments pa
              where pa.plan_id = pl.plan_id
                and pa.patient_profile_id = accounts.current_patient_profile_id()
            )
          )
        )
    )
  );

-- ====================================================================
-- FINAL NOTES
-- ====================================================================
-- 1. This schema mirrors SwiftUI flows:
--    - Accounts onboarding (patient/PT) and schedule toggles
--    - Journey map lesson ordering and PT customization
--    - Telemetry ingestion for calibration + live sessions
--    - Future-proofed content storage for patient uploads
--
-- 2. RLS policies ensure patients, PTs, and admins only see data they
--    are entitled to access. Service role bypasses policies as needed.
--
-- 3. Indexes support frequent joins (assignments, samples, lessons).
--
-- 4. Use Supabase Edge Functions or RPCs to orchestrate complex flows
--    like account provisioning or telemetry ingestion pipelines.
--
-- 5. Update Swift client models to map directly to these tables.
-- ====================================================================

