BEGIN;

SELECT policyname,
       cmd,
       roles,
       qual AS using_expr,
       with_check
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_patient_map'
ORDER BY policyname, cmd;

COMMIT;

