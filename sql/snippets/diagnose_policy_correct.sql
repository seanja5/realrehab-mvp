-- Corrected diagnostic query to check the actual policy
SELECT 
  polname as "Policy Name",
  polcmd as "Command",
  pg_get_expr(polqual, polrelid) as "USING clause",
  pg_get_expr(polwithcheck, polrelid) as "WITH CHECK clause"
FROM pg_policy
WHERE polrelid = 'telemetry.device_assignments'::regclass;

