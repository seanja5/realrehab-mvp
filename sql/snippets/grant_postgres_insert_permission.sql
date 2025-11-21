-- Grant explicit INSERT permission to postgres role on device_assignments table
-- This should bypass RLS issues since we're granting direct table permissions

BEGIN;

-- Grant INSERT, UPDATE, SELECT permissions to postgres role
-- This is in addition to RLS policies
GRANT INSERT, UPDATE, SELECT ON telemetry.device_assignments TO postgres;

-- Also grant on the devices table (in case that's needed too)
GRANT INSERT, UPDATE, SELECT ON telemetry.devices TO postgres;

-- Verify the grants
DO $$
DECLARE
  v_has_insert boolean;
BEGIN
  SELECT has_table_privilege('postgres', 'telemetry.device_assignments', 'INSERT')
  INTO v_has_insert;
  
  IF NOT v_has_insert THEN
    RAISE WARNING 'Postgres role does not have INSERT permission on device_assignments';
  ELSE
    RAISE NOTICE 'Postgres role has INSERT permission on device_assignments ✓';
  END IF;
END $$;

COMMIT;

