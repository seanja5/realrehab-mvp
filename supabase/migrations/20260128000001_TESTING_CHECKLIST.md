# Testing Checklist: Device Reassignment Fix

## Overview
This migration fixes the issue where multiple patient accounts cannot use the same physical device over time. The fix automatically deactivates previous assignments when a new user connects the same device.

## Pre-Migration State
- ❌ Account A connects device → works
- ❌ Account B connects same device → **FAILS** with `uniq_device_active_assignment` constraint violation
- ❌ Account A tries to reconnect → may fail if Account B's assignment is still active

## Post-Migration Expected Behavior
- ✅ Account A connects device → works
- ✅ Account B connects same device → **WORKS** (Account A's assignment auto-deactivated)
- ✅ Account A reconnects → **WORKS** (Account B's assignment auto-deactivated)
- ✅ Only ONE active assignment exists per device at any time

## Step-by-Step Testing

### Test 1: Initial Device Assignment
1. **Login as Account A** (patient account)
2. **Connect the physical brace** (pair device)
3. **Calibrate device** (save starting_position and maximum_position)
4. **Expected Result**: ✅ Calibration succeeds, device_assignment created with `is_active = true`

### Test 2: Device Reassignment to Different User
1. **Logout from Account A**
2. **Login as Account B** (different patient account)
3. **Connect the SAME physical brace** (same bluetooth identifier)
4. **Calibrate device** (save starting_position and maximum_position)
5. **Expected Result**: ✅ Calibration succeeds
6. **Verify in Database**:
   ```sql
   SELECT id, device_id, patient_profile_id, is_active, unpaired_at, paired_at
   FROM telemetry.device_assignments
   WHERE device_id = '<your_device_id>'
   ORDER BY paired_at DESC;
   ```
   - Should see TWO rows for this device
   - Account A's row: `is_active = false`, `unpaired_at` is set (timestamp)
   - Account B's row: `is_active = true`, `unpaired_at = NULL`

### Test 3: Reassignment Back to Original User
1. **Logout from Account B**
2. **Login as Account A** (original account)
3. **Connect the SAME physical brace**
4. **Calibrate device** (save starting_position and maximum_position)
5. **Expected Result**: ✅ Calibration succeeds
6. **Verify in Database**:
   ```sql
   SELECT id, device_id, patient_profile_id, is_active, unpaired_at, paired_at
   FROM telemetry.device_assignments
   WHERE device_id = '<your_device_id>'
   ORDER BY paired_at DESC;
   ```
   - Should see THREE rows for this device
   - Account B's row: `is_active = false`, `unpaired_at` is set
   - Account A's NEW row: `is_active = true`, `unpaired_at = NULL`
   - Account A's OLD row: `is_active = false`, `unpaired_at` is set

### Test 4: Verify Constraint Still Enforced
1. **Run this query** to verify only one active assignment per device:
   ```sql
   SELECT device_id, COUNT(*) as active_count
   FROM telemetry.device_assignments
   WHERE is_active = true
   GROUP BY device_id
   HAVING COUNT(*) > 1;
   ```
2. **Expected Result**: ✅ Returns 0 rows (no device has multiple active assignments)

### Test 5: Verify Calibration History Preserved
1. **Check calibrations** for both accounts:
   ```sql
   SELECT c.id, c.stage, c.recorded_at, da.patient_profile_id, da.is_active
   FROM telemetry.calibrations c
   JOIN telemetry.device_assignments da ON c.device_assignment_id = da.id
   WHERE da.device_id = '<your_device_id>'
   ORDER BY c.recorded_at DESC;
   ```
2. **Expected Result**: ✅ All calibrations are preserved, linked to their respective device_assignment rows

## Database Verification Queries

### Check Active Assignments
```sql
SELECT 
  da.id,
  da.device_id,
  d.hardware_serial,
  pp.first_name || ' ' || pp.last_name as patient_name,
  da.is_active,
  da.paired_at,
  da.unpaired_at
FROM telemetry.device_assignments da
JOIN telemetry.devices d ON da.device_id = d.id
JOIN accounts.patient_profiles pp ON da.patient_profile_id = pp.id
WHERE d.hardware_serial = '<your_bluetooth_identifier>'
ORDER BY da.paired_at DESC;
```

### Check Constraint Compliance
```sql
-- Should return 0 rows (no violations)
SELECT device_id, COUNT(*) as active_count
FROM telemetry.device_assignments
WHERE is_active = true
GROUP BY device_id
HAVING COUNT(*) > 1;
```

## Troubleshooting

### If Test 2 Fails (Account B cannot connect)
- Check RLS policies on `device_assignments` table
- Verify `get_or_create_device_assignment` function is updated
- Check function permissions: `GRANT EXECUTE ON FUNCTION public.get_or_create_device_assignment(text) TO authenticated;`

### If Constraint Violation Still Occurs
- Verify the function is actually updated: 
  ```sql
  SELECT pg_get_functiondef(oid) 
  FROM pg_proc 
  WHERE proname = 'get_or_create_device_assignment';
  ```
- Check if there's a race condition (unlikely but possible)
- Verify `is_active` is being set to `false` before new insert

### If Calibrations Fail After Reassignment
- Verify `device_assignment_id` in calibrations table points to correct assignment
- Check that RLS policies on `calibrations` table allow access via device_assignment

## Success Criteria
✅ All 5 tests pass  
✅ No constraint violations  
✅ Calibration history preserved for all users  
✅ Device can be reassigned multiple times without errors  
✅ Only one active assignment per device at any time

