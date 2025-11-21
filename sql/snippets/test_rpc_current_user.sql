-- Test what current_user is inside the RPC function
-- This will help us understand why the RLS policy isn't working

-- Create a test function that returns current_user
CREATE OR REPLACE FUNCTION public.test_current_user()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN current_user::text;
END;
$$;

-- Grant execute
GRANT EXECUTE ON FUNCTION public.test_current_user() TO authenticated;

-- Test it (run this via PostgREST/RPC to see what user it returns)
-- SELECT public.test_current_user();

