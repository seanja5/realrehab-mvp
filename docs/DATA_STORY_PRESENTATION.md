# RealRehab Data Story - Professor Presentation

**RealRehab**: Connecting patients and physical therapists through sensor-guided rehabilitation.

*Layout: Each slide title = user action. Left = app screen (add screenshot). Right = data stored (Supabase tables/columns).*

---

## Part A: Project to Date

### Slide 1: Logical Sequence (Project to Date)

**First** → **Second** → **Third**

| Order | Module | What happens |
|-------|--------|--------------|
| 1 | Identity | Sign up, login, patient links to PT |
| 2 | Prescription | PT saves rehab plan for patient |
| 3 | Device + Calibration | Patient pairs knee brace, calibrates |

*Then: Schedule → Do Lesson → Lesson Engine (during) → View Progress*

---

### Slide 2: Sign Up, Login, Link to PT

**Action**: User signs up (email, password), logs in, or patient enters PT access code.

**Left**: Screenshot of sign-up, login, or "Link to PT" (access code) screen.  
**Right**: Data stored (see table below).

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| email, password | Supabase Auth | auth.users | Permanent |
| user_id, role, email, first_name, last_name, phone | AuthService.ensureProfile | accounts.profiles | Permanent |
| profile_id, date_of_birth, gender, surgery_date, phone | PatientService | accounts.patient_profiles | Permanent |
| profile_id, practice_name, license_number, npi_number | PTService | accounts.pt_profiles | Permanent |
| patient_profile_id, pt_profile_id, status | RPC link_patient_via_access_code | accounts.pt_patient_map | Permanent |
| authProfile, resolvedSession | CacheService | Device cache | 24h–7 days (offline) |

---

### Slide 3: PT Saves Rehab Plan

**Action**: PT selects patient, builds journey map (lessons, reps, rest), taps Confirm.

**Left**: Screenshot of PT Journey Map or Confirm Journey screen.  
**Right**: Data stored (see table below).

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| pt_profile_id, patient_profile_id, category, injury, status, nodes (JSONB), notes | RehabService.saveACLPlan | accounts.rehab_plans | Permanent |
| rehabPlan, plan | CacheService | Device cache | 5–10 min |

---

### Slide 4: Patient Pairs Device + Calibrates

**Action**: Patient pairs BLE knee brace; holds starting position, then max extension.

**Left**: Screenshot of Pair Device or Calibrate screen.  
**Right**: Data stored (see table below).

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| hardware_serial, status | RPC get_or_create_device_assignment | telemetry.devices | Permanent |
| device_id, patient_profile_id, pt_profile_id | RPC | telemetry.device_assignments | Permanent |
| device_assignment_id, stage, flex_value, knee_angle_deg | TelemetryService.saveCalibration | telemetry.calibrations | Permanent |
| calibrationPoints | CacheService | Device cache | 10 min |

---

### Slide 5: Patient Sets Schedule

**Action**: Patient selects days and 30‑min slots; toggles Allow Reminders.

**Left**: Screenshot of My Schedule or schedule picker screen.  
**Right**: Data stored (see table below).

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| patient_profile_id, day_of_week, slot_time | ScheduleService.saveSchedule | accounts.patient_schedule_slots | Permanent |
| schedule_reminders_enabled | PatientService.setScheduleRemindersEnabled | accounts.patient_profiles | Permanent |
| patientSchedule | CacheService | Device cache | 24h |
| T-15, T notifications | NotificationManager | iOS local | 14-day window |

---

### Slide 6: Patient Does Lesson

**Action**: Patient taps Begin Lesson, performs reps, pauses or completes.

**Left**: Screenshot of lesson screen (green/red box, rep count).  
**Right**: Data stored (see table below).

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| lesson_id, reps_completed, reps_target, elapsed_seconds, status | LocalLessonProgressStore | RealRehabLessonProgress/{lessonId}.json | Until sync/complete |
| Same payload | OutboxSyncManager | RealRehabOutbox/outbox.json | Until sync succeeds |
| Same payload | RPC upsert_patient_lesson_progress | accounts.patient_lesson_progress | Permanent |
| lessonProgress | CacheService | Device cache | 10 min |

---

### Slide 7: Lesson Engine (During Lesson – Screen Only)

**Action**: Patient moves leg; sensors check pace and form every 100ms.

**Left**: Screenshot of lesson screen showing green or red feedback.  
**Right**: Not stored (screen only). See table for what is processed.

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| flex_value, IMU value (raw) | Convert to degrees; compare to animation | Screen (green/red) | Not stored |
| — | validateMaxReached (10°), validateMovementSpeed (25°), validateIMU (±7) | — | — |

*Nothing persisted today. Future: Bucket G will store error counts.*

---

### Slide 8: Patient or PT Views Progress

**Action**: Patient/PT opens journey map; sees reps done per lesson.

**Left**: Screenshot of Journey Map with progress bars.  
**Right**: Data read from (see table below).

| Data used | Processing | Where read from | Duration |
|-----------|------------|-----------------|----------|
| patient_profile_id, lesson_id, reps_completed, reps_target, status | RehabService.getLessonProgress | accounts.patient_lesson_progress | Permanent |
| Merged with local draft | — | LocalLessonProgressStore | Until sync |
| lessonProgress | CacheService | Device cache | 10 min |

---

## Part B: Next Three Future Modules

### Slide 9: Logical Sequence (Future)

**First** → **Second** → **Third**

| Order | Module | What happens |
|-------|--------|--------------|
| 1 | Schedule | Patient picks days and times (already done) |
| 2 | Sensor Insights | Store error counts from lesson (Bucket G) |
| 3 | Data Analysis | PT views trends and recovery charts |

---

### Slide 10: Future – Sensor Insights (Bucket G)

**Action**: Lesson turns red or green; app counts each error type.

**Left**: Same as Slide 7 (lesson screen).  
**Right**: Data stored (see table below).

| Data to collect | Processing | Where stored | Duration |
|-----------------|------------|--------------|----------|
| valgus_left_count, valgus_right_count, max_not_reached_count, speed_too_slow_count, speed_too_fast_count, shake_count, anterior_migration_count | LessonView validation; aggregate on rep/pause/complete | RealRehabSensorInsights (device) → Outbox → accounts.lesson_sensor_insights (cloud) | Device until sync; Cloud permanent |

---

### Slide 11: Future – Schedule (Already Done)

**Action**: Patient picks days and times; toggles reminders.

**Left**: Screenshot of My Schedule screen.  
**Right**: Data stored (see table below).

| Data collected | Processing | Where stored | Duration |
|----------------|------------|--------------|----------|
| patient_profile_id, day_of_week, slot_time | ScheduleService | accounts.patient_schedule_slots | Permanent |
| schedule_reminders_enabled | PatientService | accounts.patient_profiles | Permanent |

---

### Slide 12: Future – Data Analysis

**Action**: PT queries by patient and date; views trends and recovery charts.

**Left**: Screenshot of PT dashboard with trends (future UI).  
**Right**: Data read from (see table below).

| Data used | Processing | Where read from | Duration |
|-----------|------------|-----------------|----------|
| lesson_quality_metrics, lesson_stability_metrics, lesson_biomechanics_metrics | Queries by patient_profile_id, date range | Cloud (read-only) | — |

---

## Slide Layout Notes

- **Left**: Add screenshot of the app screen for that action.
- Slides 1–12. Slide 1 = sequence (project). Slide 9 = sequence (future).
- **Right**: Use the tables above (or a simplified box) showing Supabase table.column and storage location.
- Mermaid: [mermaid.live](https://mermaid.live) for any diagrams. Export PNG/SVG for slides.
