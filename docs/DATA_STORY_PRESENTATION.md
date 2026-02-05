# RealRehab Data Story — Module-Based Presentation

**Problem:** Patients and physical therapists need a way to connect and track sensor-guided rehabilitation.

**Solution:** RealRehab connects patients and PTs through an app that captures calibration, lesson feedback, and progress—stored locally and in the cloud.

**This deck explains the RealRehab data story across 6 functional modules.**

---

## Slide: Data Story Legend

| Term | Meaning |
|------|---------|
| **Cloud** | Supabase (PostgreSQL). Tables in `accounts`, `telemetry`, `rehab` schemas. |
| **Device** | JSON files on disk (e.g., `RealRehabLessonProgress/`, `RealRehabOutbox/`, `RealRehabCache/`). |
| **Cache** | Memory + optional disk. Short TTL for UI; invalidated on write. |
| **Screen-only** | Displayed to user but not persisted. |
| **Raw** | Data stored or captured as-is (e.g., raw flex sensor value). |
| **Processed** | Transformed before storage (e.g., raw flex → degrees; password hashed). |

---

## Slide: Logical Sequence (Project to Date)

**Modules 1 → 2 → 3**

| # | Module | What happens |
|---|--------|--------------|
| 1 | Identity & Account Data | Sign up, login, onboarding, patient links to PT |
| 2 | PT Creates Rehab Plan | PT builds journey map (Knee/ACL, phases, lessons, parameters) and saves |
| 3 | Lesson Engine | Calibrate → realtime feedback → reassessment → range gained |

---

## MODULE 1 — Identity & Account Data

### Slide: What the User Does

**User Action**
- Signs up (email, password) or logs in
- Completes onboarding (patient: DOB, gender, surgery date, phone; PT: practice name, license, NPI)
- Patient enters PT access code to link; PT adds patient via RPC

**Suggested Screenshot:** Sign-up, login, or “Link to PT” (access code) screen.

---

### Slide: Identity — Data Movement

| App Action | Data Captured | Processing (Raw→Processed) | Storage & Retention |
|------------|---------------|----------------------------|---------------------|
| Sign up / login | email, password, first_name, last_name | Password hashed by Supabase Auth; profile upserted | Cloud: auth.users, accounts.profiles |
| Patient onboarding | date_of_birth, gender, surgery_date, phone | Save as-is | Cloud: accounts.patient_profiles |
| PT onboarding | practice_name, license_number, npi_number | Save as-is | Cloud: accounts.pt_profiles |
| Link via access code | access_code (trimmed), patient_profile_id | Trim; RPC lookup; DB generates unique code on create | Cloud: accounts.pt_patient_map |
| Session / profile | — | — | Device: cache (session, authProfile; 24h–7 days offline) |

**Data form:** Identity is Supabase-only per DATA_FLOW; cache holds session/profile for offline use.

**Suggested Screenshot:** Profile or “Link to PT” confirmation.

**Why it matters:** Foundation for all flows; enables secure login and PT–patient linking.

---

## MODULE 2 — PT Creates Rehab Plan

### Slide: PT Journey Map Creation

**User Action**
- PT selects patient
- Builds journey map: Knee/ACL, phases (1–4), lesson order and types (lesson vs benchmark)
- Sets parameters per node: reps, restSec, sets, restBetweenSets, kneeBendAngle, timeHoldingPosition
- Taps Confirm Journey

**Suggested Screenshot:** PT Journey Map or Confirm Journey screen.

---

### Slide: Rehab Plan — Data Movement

| App Action | Data Captured | Processing (Raw→Processed) | Storage & Retention |
|------------|---------------|----------------------------|---------------------|
| Confirm Journey | Plan metadata: category, injury, status, notes | Archive existing active plan; hardcode category=Knee, injury=ACL; trim notes | Cloud: accounts.rehab_plans |
| Confirm Journey | Lesson nodes: order, nodeType, phase, reps, restSec, sets, restBetweenSets, kneeBendAngle, timeHoldingPosition, title, icon, isLocked | Convert LessonNode→PlanNodeDTO; encode JSONB | Cloud: accounts.rehab_plans (nodes JSONB) |
| — | Plan | Invalidate cache | Device: cache (short TTL for UI) |

**Data form:** Processed (nodes encoded as JSONB); cached short TTL.

**Suggested Screenshot:** Journey Map with lesson nodes visible.

**Why it matters:** Supports PT prescription; defines what the patient will do in each lesson.

---

## MODULE 3 — Lesson Engine

### Slide: Lesson Engine — Step 1: Calibration (Before)

**User Action**
- Patient taps “Set Starting Position” (leg bent ~90°)
- Patient taps “Set Maximum Position” (leg fully extended)

**Data Captured**
- Raw flex sensor value (185–300) → convertToDegrees() → flex_value (degrees)
- stage (starting_position | maximum_position), knee_angle_deg, recorded_at

**Processing (Raw→Processed)**
- Raw sensor → degrees; TelemetryService.saveCalibration; invalidate calibration cache

**Storage & Retention**
- Cloud: telemetry.calibrations
- Device: cache (calibrationPoints; used when lesson loads)

**Suggested Screenshot:** Calibrate Device screen with start/max set.

---

### Slide: Lesson Engine — Step 2: Realtime Feedback (During)

**User Action**
- Patient moves leg through reps; flex sensor and IMU stream continuously

**Data Captured**
- Raw flex sensor value, raw IMU value; calibration rest/max degrees (read from step 1); PT-set restSec per lesson

**Processing (Raw→Processed)**
- Every 100ms: convert flex to degrees; compare to animation; validate max (10°), pace (25°), IMU (±7); show green or red

**Storage & Retention**
- **Screen-only — not persisted.** Future: Bucket G will store error counts.

**Suggested Screenshot:** Lesson screen with green/red feedback.

---

### Slide: Lesson Engine — Step 3: Reassessment (After)

**User Action**
- Patient extends leg to max again; taps “Set Maximum Position”

**Data Captured**
- Raw flex sensor value → convertToDegrees() → flex_value (degrees), stage (maximum_position), recorded_at

**Processing (Raw→Processed)**
- Convert raw to degrees; TelemetryService.saveCalibration; invalidate calibration cache

**Storage & Retention**
- Cloud: telemetry.calibrations
- Device: cache invalidated

**Suggested Screenshot:** Reassessment screen.

---

### Slide: Lesson Engine — Step 4: Range Gained (Computed)

**User Action**
- Patient views Completion screen; app displays range gained

**Data Captured**
- Original max (from calibration); reassessment max (from step 3)

**Processing (Raw→Processed)**
- TelemetryService.getAllMaximumCalibrationsForPatient; take two most recent maximum_position records; compute difference (reassessment max − original max)

**Storage & Retention**
- Cloud: rehab.session_metrics.range_of_motion_deg or derived from telemetry.calibrations
- Device: cache for display

**Data form:** Derived from calibrations; may be stored or computed on read.

**Suggested Screenshot:** Completion screen with “Range: +X°”.

**Why it matters:** Shows improvement per lesson; supports recovery tracking.

---

## Slide: Logical Sequence (Future Modules)

**Modules 4 → 5 → 6**

| # | Module | What happens |
|---|--------|--------------|
| 4 | Scheduling | Patient picks days and 30-min slots; toggles reminders |
| 5 | Lesson Progress Saving | Offline-first: save reps, elapsed time, status; sync when online |
| 6 | Sensor Insights | Persist error counts from lesson (currently screen-only) |

---

## MODULE 4 — Scheduling

### Slide: Scheduling — Data Movement

**User Action**
- Patient selects days and 30-min slots; taps Confirm Schedule
- Patient toggles Allow Reminders

**Data Captured**
- patient_profile_id, day_of_week (0–6), slot_time (HH:mm:ss)
- schedule_reminders_enabled (boolean)

**Processing (Raw→Processed)**
- Replace old slots with new; parse slot_time; compute T-15 and T triggers for 14-day rolling window; schedule iOS notifications

**Storage & Retention**
- Cloud: accounts.patient_schedule_slots, accounts.patient_profiles (reminder flag)
- Device: cached schedule; iOS local notification schedule (14-day window)

**Suggested Screenshot:** My Schedule screen.

**Why it matters:** Supports engagement; reminders keep patients on track.

---

## MODULE 5 — Lesson Progress Saving

### Slide: Offline-First Progress Story

**User Action**
- Patient taps Begin Lesson; performs reps; pauses, leaves, or completes
- PT or patient opens Journey Map to view progress

**Suggested Screenshot:** Lesson screen with rep count, or Journey Map with progress bars.

---

### Slide: Lesson Progress — Data Movement

| App Action | Data Captured | Processing (Raw→Processed) | Storage & Retention |
|------------|---------------|----------------------------|---------------------|
| Rep/pause/complete | lesson_id, reps_completed, reps_target, elapsed_seconds, status | Store draft for offline resume | Device: RealRehabLessonProgress/{lessonId}.json |
| — | Same payload | Queue for upload when online | Device: RealRehabOutbox/outbox.json |
| When online | Same payload | RPC validates status (inProgress \| completed); upsert | Cloud: accounts.patient_lesson_progress |
| View Journey Map | — | Read from cloud; merge with local draft | Device: cache (lessonProgress) |

**Data form:** Raw (passed through); RPC validates status. Draft until sync; permanent in cloud when synced.

**Suggested Screenshot:** Journey Map with progress bars.

**Why it matters:** Enables offline use; progress not lost if connection drops.

---

## MODULE 6 — Sensor Insights (Future)

### Slide: Sensor Insights — Future Data Movement

**Context**
- Today: Realtime green/red feedback is screen-only and not persisted.
- Future: App will persist error counts for PT dashboard.

**Data Captured**
- Event/error counts: speed errors, max not reached, IMU drift, shake, anterior migration (examples from DATA_FLOW.md)

**Processing (Raw→Processed)**
- Same validation as Lesson Engine; aggregate counts when rep ends or lesson pauses; queue for upload when online

**Storage & Retention**
- Device: RealRehabSensorInsights/{lessonId}.json → Outbox
- Cloud: Planned table (e.g., accounts.lesson_sensor_insights or lesson_quality_metrics, lesson_stability_metrics, lesson_biomechanics_metrics per DATA_FLOW.md)

**Suggested Screenshot:** Lesson screen (same as Module 3 Step 2); future PT dashboard with metrics.

**Why it matters:** PT can see movement quality trends; supports data-driven rehab decisions.

---

## Slide Layout Notes

- Use consistent subheadings: User Action, Data Captured, Processing (Raw→Processed), Storage & Retention, Suggested Screenshot.
- Max ~6 bullets per section; prefer 4-box or 3-column layouts over large tables.
- Left: screenshot; Right: data flow summary.
- Mermaid: [mermaid.live](https://mermaid.live) for diagrams; export PNG/SVG for slides.
