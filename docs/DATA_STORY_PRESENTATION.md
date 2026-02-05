# RealRehab Data Story - Professor Presentation

**RealRehab**: Connecting patients and physical therapists through sensor-guided rehabilitation.

*Layout: Each slide title = user action. Left = app screen (add screenshot). Right = data stored (Supabase tables/columns).*

---

## Part A: Project to Date (First 3 Modules)

### Slide 1: Logical Sequence (Project to Date)

**First** → **Second** → **Third**

| Order | Module | What happens |
|-------|--------|--------------|
| 1 | Identity | Sign up, login, patient links to PT |
| 2 | PT Creates Rehab Plan | PT saves knee/ACL plan with lesson nodes, order, types, parameters |
| 3 | Lesson Engine | Calibrate (min/max) → do lesson (green/red) → reassessment (new max) → range gained |

---

### Slide 2: Sign Up, Login, Link to PT

**Action**: User signs up, logs in, or patient enters PT access code.

**Left**: Screenshot of sign-up, login, or "Link to PT" screen.  
**Right**: Data stored (see table below).

| Transaction | Processing | Where stored |
|-------------|------------|--------------|
| Credentials, profile fields | Auth + profile services | Cloud: auth.users, accounts.profiles |
| Patient/PT profile data | Profile services | Cloud: accounts.patient_profiles, accounts.pt_profiles |
| Patient–PT link | RPC link_patient_via_access_code | Cloud: accounts.pt_patient_map |
| Session, profile | Cache | Device: cache (offline) |

---

### Slide 3: PT Creates Rehab Plan

**Action**: PT selects patient, builds journey map (Knee/ACL, phases, lesson order and types, parameters per lesson), taps Confirm.

**Left**: Screenshot of PT Journey Map or Confirm Journey screen.  
**Right**: Data stored (see table below).

| Transaction | Processing | Where stored |
|-------------|------------|--------------|
| Plan metadata (category, injury, status, notes) | RehabService.saveACLPlan | Cloud: accounts.rehab_plans |
| Lesson nodes (order, nodeType, phase, reps, restSec, sets, restBetweenSets, kneeBendAngle, timeHoldingPosition, title, icon, isLocked) | RehabService.saveACLPlan | Cloud: accounts.rehab_plans (nodes JSONB) |
| Plan | Cache | Device: cache (short TTL) |

---

### Slide 4: Lesson Engine – Calibration, Realtime, Reassessment, Range Gained

**Left**: Screenshots of Calibrate, Lesson (green/red), Reassessment, Completion screens.  
**Right**: For each step, Application → Transaction → Processing → Destination.

| Step | Application | Transaction | Processing | Destination |
|------|-------------|-------------|------------|-------------|
| **1. Calibration** | Patient taps Set Starting Position, then Set Maximum Position | stage, flex_value, knee_angle_deg | TelemetryService.saveCalibration | Cloud: telemetry.calibrations; Device: cache |
| **2. Realtime** | Patient moves leg through reps | Raw flex, IMU; calibration rest/max | Convert to degrees; compare to animation; validate | Screen only (green/red – not persisted) |
| **3. Reassessment** | Patient extends to max again; taps Set Maximum Position | stage (maximum_position), flex_value | TelemetryService.saveCalibration | Cloud: telemetry.calibrations |
| **4. Range Gained** | Patient views Completion screen | Original max, reassessment max | Compute difference | Cloud: rehab.session_metrics or derived; Device: cache |

*Realtime green/red not persisted. Future: Bucket G will store error counts.*

---

## Part B: Next Three Future Modules

### Slide 5: Logical Sequence (Future)

**Fourth** → **Fifth** → **Sixth**

| Order | Module | What happens |
|-------|--------|--------------|
| 4 | Scheduling | Patient picks days and times (already done) |
| 5 | Progress Saving | Save reps done, elapsed time, status per lesson |
| 6 | Sensor Insights | Store error counts from lesson (Bucket G) |

---

### Slide 6: Scheduling (Already Done)

**Action**: Patient selects days and 30‑min slots; toggles Allow Reminders.

**Left**: Screenshot of My Schedule screen.  
**Right**: Data stored (see table below).

| Transaction | Processing | Where stored |
|-------------|------------|--------------|
| Days, slot times | ScheduleService | Cloud: accounts.patient_schedule_slots |
| Reminder preference | PatientService | Cloud: accounts.patient_profiles |
| Schedule, notifications | Cache, NotificationManager | Device: cache, iOS local |

---

### Slide 7: Progress Saving

**Action**: Patient taps Begin Lesson, performs reps, pauses or completes.

**Left**: Screenshot of lesson screen with rep count.  
**Right**: Data stored (see table below).

| Transaction | Processing | Where stored |
|-------------|------------|--------------|
| lesson_id, reps_completed, reps_target, elapsed_seconds, status | LocalLessonProgressStore | Device: RealRehabLessonProgress |
| Same payload | OutboxSyncManager | Device: RealRehabOutbox |
| Same payload | RPC upsert_patient_lesson_progress | Cloud: accounts.patient_lesson_progress |
| Progress | Cache | Device: cache |

---

### Slide 8: Sensor Insights (Future – Bucket G)

**Action**: Lesson turns red or green; app counts each error type.

**Left**: Same as Slide 4 (lesson screen).  
**Right**: Data to be stored (see table below).

| Transaction | Processing | Where stored |
|-------------|------------|--------------|
| Error counts (valgus, max_not_reached, speed, shake, anterior_migration, etc.) | LessonView validation; aggregate on rep/pause/complete | Device: RealRehabSensorInsights → Outbox → Cloud: accounts.lesson_sensor_insights |

---

## Slide Layout Notes

- **Left**: Add screenshot of the app screen for that action.
- Slides 1–8. Slide 1 = sequence (project). Slide 5 = sequence (future).
- **Right**: Use the tables above (or a simplified box) showing Supabase table.column and storage location.
- Mermaid: [mermaid.live](https://mermaid.live) for any diagrams. Export PNG/SVG for slides.
