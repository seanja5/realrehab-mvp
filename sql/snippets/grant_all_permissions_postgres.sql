-- Grant ALL permissions to postgres role on device_assignments table
-- This should definitely work since postgres is the table owner

BEGIN;

-- Check current permissions
DO $$
DECLARE
  v_table_owner text;
  v_has_insert boolean;
BEGIN
  -- Check table owner
  SELECT tableowner INTO v_table_owner
  FROM pg_tables
  WHERE schemaname = 'telemetry'
    AND tablename = 'device_assignments';
  
  RAISE NOTICE 'Table owner: %', v_table_owner;
  
  -- Check if postgres has INSERT
  SELECT has_table_privilege('postgres', 'telemetry.device_assignments', 'INSERT')
  INTO v_has_insert;
  
  RAISE NOTICE 'Postgres has INSERT permission: %', v_has_insert;
END $$;

-- Grant ALL permissions to postgres (should already have them as owner, but let's be explicit)
GRANT ALL ON telemetry.device_assignments TO postgres;
GRANT ALL ON telemetry.devices TO postgres;

-- Also grant to authenticated role (in case that's needed)
GRANT INSERT, SELECT, UPDATE ON telemetry.device_assignments TO authenticated;
GRANT INSERT, SELECT, UPDATE ON telemetry.devices TO authenticated;

-- Verify grants
DO $$
DECLARE
  v_postgres_insert boolean;
  v_authenticated_insert boolean;
BEGIN
  SELECT has_table_privilege('postgres', 'telemetry.device_assignments', 'INSERT')
  INTO v_postgres_insert;
  
  SELECT has_table_privilege('authenticated', 'telemetry.device_assignments', 'INSERT')
  INTO v_authenticated_insert;
  
  IF NOT v_postgres_insert THEN
    RAISE EXCEPTION 'Postgres role does NOT have INSERT permission';
  END IF;
  
  RAISE NOTICE 'Postgres has INSERT: %, Authenticated has INSERT: %', v_postgres_insert, v_authenticated_insert;
END $$;

COMMIT;

