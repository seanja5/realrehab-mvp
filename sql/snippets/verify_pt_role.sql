-- Verify that your user account has role='pt' set correctly
-- Run this while logged in as your PT user

BEGIN;

-- Check your current profile
SELECT 
  id,
  user_id,
  email,
  role,
  first_name,
  last_name,
  auth.uid() as current_auth_uid
FROM accounts.profiles
WHERE user_id = auth.uid();

-- Check if you have a pt_profiles row
SELECT 
  pp.id,
  pp.profile_id,
  pp.email,
  p.role,
  p.user_id
FROM accounts.pt_profiles pp
INNER JOIN accounts.profiles p ON pp.profile_id = p.id
WHERE p.user_id = auth.uid();

COMMIT;

