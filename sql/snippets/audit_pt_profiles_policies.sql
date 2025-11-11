BEGIN;

SELECT policyname,
       cmd,
       roles,
       qual AS using_expr,
       with_check
FROM pg_policies
WHERE schemaname = 'accounts'
  AND tablename = 'pt_profiles'
ORDER BY policyname, cmd;

COMMIT;

