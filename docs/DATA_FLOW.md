# RealRehab Data Flow Documentation

Comprehensive data flow analysis and visual documentation for the RealRehab app. Organizes all data into buckets, identifies the top 3 most impactful modules, and shows Application (user action) → Transaction (what is captured) → Processing (raw kept or transformed) → Destination (Supabase vs local storage).

---

## 1. Complete Data Inventory

### Supabase Tables (Cloud Storage)

| Schema    | Table                          | Key Fields                                                                                                                                  | Used By                               |
| --------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| accounts  | profiles                       | user_id, role, email, first_name, last_name, phone                                                                                          | AuthService                           |
| accounts  | patient_profiles               | profile_id, date_of_birth, gender, surgery_date, last_pt_visit, allow_notifications, allow_camera, schedule_reminders_enabled, intake_notes | PatientService                        |
| accounts  | pt_profiles                    | profile_id, practice_name, license_number, npi_number, contact_email, contact_phone                                                         | PTService                             |
| accounts  | pt_patient_map                 | patient_profile_id, pt_profile_id, status, assigned_at                                                                                      | PatientService, PTService             |
| accounts  | patient_schedule_slots         | patient_profile_id, day_of_week, slot_time                                                                                                  | ScheduleService                       |
| accounts  | rehab_plans                    | pt_profile_id, patient_profile_id, category, injury, status, nodes (JSONB), notes                                                           | RehabService                          |
| accounts  | patient_lesson_progress        | patient_profile_id, lesson_id, reps_completed, reps_target, elapsed_seconds, status                                                         | RehabService, OutboxSyncManager (RPC) |
| rehab     | assignments, programs, lessons | (legacy - program-based)                                                                                                                    | RehabService (partial)                |
| telemetry | devices, device_assignments    | bluetooth_serial, patient_profile_id, pt_profile_id                                                                                         | TelemetryService (RPC)                |
| telemetry | calibrations                   | device_assignment_id, stage, flex_value, knee_angle_deg, recorded_at                                                                        | TelemetryService                      |

### Local Storage (Disk)

| Location                                  | Format | Data                                                                   | Purpose                                                                                                             |
| ----------------------------------------- | ------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `RealRehabLessonProgress/{lessonId}.json` | JSON   | lessonId, repsCompleted, repsTarget, elapsedSeconds, updatedAt, status | Offline lesson draft resume ([LocalLessonProgressStore](../RealRehabPractice/Services/LocalLessonProgressStore.swift)) |
| `RealRehabOutbox/outbox.json`             | JSON   | OutboxItem[] (LessonProgressPayload)                                   | Pending sync queue when offline ([OutboxSyncManager](../RealRehabPractice/Services/Outbox/OutboxSyncManager.swift))    |
| `RealRehabCache/*.json`                   | JSON   | Cached API responses                                                   | Memory + disk cache ([CacheService](../RealRehabPractice/Services/Cache/CacheService.swift))                           |
| `RealRehabSensorInsights/{lessonId}.json` | JSON   | Sensor event counts (valgus, max_not_reached, speed errors, shake, etc.) | FUTURE: Offline sensor insights draft; syncs via Outbox when online                                                      |

### Cache Keys (Local - Memory + Optional Disk)

From [CacheKey.swift](../RealRehabPractice/Services/Cache/CacheKey.swift): patientProfile, patientEmail, hasPT, ptProfile, ptInfo, ptProfileIdFromPatient, rehabPlan, patientList, patientDetail, activeAssignment, program, lessons, authProfile, patientProfileId, patientSchedule, scheduleRemindersEnabled, calibrationPoints, lessonProgress, plan, resolvedSession.

---

## 2. Data Buckets (Modules by User Flow)

### Bucket A: Identity and Account Data (incl. PT-Patient Management)

- **Tables**: profiles, patient_profiles, pt_profiles, pt_patient_map
- **Data**: email, password, role, first_name, last_name, phone, DOB, gender, surgery_date, access_code, practice_name, license_number, NPI, patient_profile_id, pt_profile_id
- **Flow**: Sign up → Supabase Auth + profiles; Create account → patient_profiles/pt_profiles; Patient links via access code → pt_patient_map (RPC); PT adds patient → pt_patient_map (RPC); PT deletes mapping → pt_patient_map (RPC); PT views list/detail → Supabase → Cache
- **Storage**: Supabase; Cache for PT list/detail

### Bucket B: PT Creates Rehab Plan

- **Tables**: accounts.rehab_plans
- **Data**: Plan metadata (category, injury, status, notes); Lesson nodes as JSONB: order, node types (lesson vs benchmark), phase (1–4), lesson parameters (reps, restSec, sets, restBetweenSets, kneeBendAngle, timeHoldingPosition), title, icon, isLocked
- **Flow**: PT selects patient → builds journey map (Knee/ACL, phases, lesson order, types within each phase, parameters per lesson) → taps Confirm → RehabService.saveACLPlan → Supabase rehab_plans; Cache invalidated
- **Storage**: Cloud (Supabase); Cache for UI (short TTL)

### Bucket C: Schedule Data

- **Tables**: patient_schedule_slots, patient_profiles.schedule_reminders_enabled
- **Data**: day_of_week (0-6), slot_time (HH:mm:ss), boolean for reminders
- **Flow**: Patient sets schedule → Supabase patient_schedule_slots; Toggle reminders → Supabase patient_profiles; NotificationManager schedules local notifications from slots
- **Storage**: Supabase; Cache for UI; Notifications stored locally by iOS

### Bucket D: Device Pairing

- **Tables**: telemetry.devices, telemetry.device_assignments
- **Data**: bluetooth_identifier, device_id, patient_profile_id, pt_profile_id
- **Flow**: Pair device → RPC get_or_create_device_assignment → telemetry.devices, telemetry.device_assignments
- **Storage**: Supabase only. *Calibration data (min/max) is in Bucket F (Lesson Engine).*

### Bucket F: Lesson Engine – Calibration, Realtime Display, Reassessment, Range Gained

- **Tables**: telemetry.calibrations, telemetry.devices, telemetry.device_assignments; rehab.session_metrics (range_of_motion_deg for range gained)
- **Data**: Calibration (stage, flex_value, knee_angle_deg); raw flex/IMU during lesson; reassessment max; range gained (computed: reassessment max − original max)
- **Flow**: (1) Patient calibrates: starting_position, maximum_position → TelemetryService.saveCalibration → telemetry.calibrations; cache. (2) Patient does lesson: flex/IMU stream → convert to degrees (uses calibration) → compare to animation → green/red on screen (not stored). (3) Reassessment after lesson: patient extends to max → save new maximum_position → telemetry.calibrations. (4) Range gained: original max + reassessment max → compute difference → display; stored locally and in cloud (rehab.session_metrics or derived from calibrations)
- **Storage**: Calibration and reassessment → Cloud (telemetry.calibrations); Device (cache). Range gained → computed from calibrations; stored locally (cache) and cloud (rehab.session_metrics or calibration-derived). Realtime green/red → screen only (Bucket G future for error counts).
- **Tolerances** (from LessonView/LessonEngine): Flex position = 25° (keep pace); Max extension = 10°; IMU = ±7 (keep thigh centered). PT sets rep speed via restSec per lesson.

### Bucket G: Sensor-Based Raw Insights (During Lesson) – FUTURE

- **Tables**: accounts.lesson_sensor_insights (or lesson_quality_metrics, lesson_stability_metrics, lesson_biomechanics_metrics)
- **Data**: All events from Bucket F (speed errors, max not reached, IMU drift, etc.) plus shake, anterior migration – persisted as counts
- **Flow**: Same as Bucket F validation → increment counters → Local file (RealRehabSensorInsights) + Outbox → RPC when online → Supabase; PT views via dashboard
- **Storage**: Local-first (RealRehabSensorInsights, Outbox); Supabase when synced

### Bucket H: Lesson Progress (Saving Reps and Status)

- **Tables**: accounts.patient_lesson_progress
- **Data**: lesson_id, reps_completed, reps_target, elapsed_seconds, status
- **Flow**: Patient does lesson → LocalLessonProgressStore (disk) → OutboxSyncManager (disk) → RPC upsert when online → Supabase patient_lesson_progress; PT/Patient views journey map → Supabase → Cache → UI
- **Storage**: Local-first (draft + outbox); Cloud when synced

---

## 3. Top 3 Most Impactful Buckets (Project to Date)

| Rank | Bucket                             | Rationale                                                                                                                                                                                         |
| ---- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | **Identity and Account Data**      | Foundation for all flows. Auth, profiles, PT-patient linking. Every user touches this on signup, login, and profile/link actions.                                                                 |
| 2    | **PT Creates Rehab Plan**          | Core prescription flow. PT defines knee/ACL plan, phases, lesson order, types, and parameters (reps, restSec, sets, etc.). Stored in rehab_plans.                                                  |
| 3    | **Lesson Engine** | Calibration (min/max) → lesson (green/red) → reassessment (new max) → range gained. Calibration and reassessment in telemetry.calibrations; range gained computed and stored locally + cloud. Realtime feedback uses calibration; not persisted (Bucket G future). |

*Schedule (Bucket C), Lesson Progress (Bucket H), and Sensor Insights (Bucket G) support the core flow.*

---

## 4. Data Flow Diagrams

For each bucket, the diagram uses four subgraphs in order:

- **Application**: What the user or sensor does (e.g., "Patient taps Begin Lesson", "PT saves plan")
- **Transaction**: What information is captured first (e.g., "Plan metadata and nodes", "Reps done, reps goal, time spent")
- **Processing**: What the app does with that data—raw kept or transformed. Processing may happen on **Device** (before data reaches cloud) or in **Cloud** (RPC, trigger, Supabase Auth).
- **Destination**: Where it goes (cloud database or device storage)

**Two processing patterns:**
- **Device → Cloud**: Transaction → Processing on device → Destination (cloud or device). Data is transformed before it reaches the database.
- **Transaction → Cloud → Process**: Transaction → Sent to cloud → Processing runs in cloud (RPC, trigger, Auth). Data reaches the database first; processing happens there.

### Bucket B: PT Creates Rehab Plan

*Processing: **Device**. Transaction → Device processes → Cloud.*

```mermaid
flowchart TB
    subgraph appB [Application - User Actions]
        AB1[PT selects patient]
        AB2[PT builds journey map: Knee/ACL, phases, lesson order]
        AB3[PT sets lesson types and parameters per node]
        AB4[PT taps Confirm Journey]
    end

    subgraph txB [Transaction - What is captured]
        TB1[Plan metadata: category, injury, status, notes]
        TB2[Lesson nodes: order, nodeType, phase, reps, restSec, sets, restBetweenSets, kneeBendAngle, timeHoldingPosition, title, icon, isLocked]
    end

    subgraph procB [Processing - Device]
        PB1[Archive existing active plan for patient]
        PB2[Convert LessonNode to PlanNodeDTO; encode JSONB; hardcode category=Knee injury=ACL; trim notes]
        PB3[Invalidate plan cache]
    end

    subgraph destB [Destination]
        DB1[(Cloud: accounts.rehab_plans)]
        DB2[Device: cached plan for UI]
    end

    AB1 --> AB2 --> AB3 --> AB4
    AB4 --> TB1
    AB4 --> TB2
    TB1 --> PB1
    TB2 --> PB2
    PB1 --> PB2
    PB2 --> DB1
    PB3 --> DB2
```

### Bucket D: Device Pairing

*Processing: **Cloud**. Transaction → Sent to RPC → RPC processes in cloud (creates device, assignment) → Cloud.*

```mermaid
flowchart TB
    subgraph appD [Application - User Actions]
        AD1[Patient pairs BLE knee brace]
    end

    subgraph txD [Transaction - What is captured]
        TD1[bluetooth_identifier]
    end

    subgraph procD [Processing - Cloud]
        PD1[RPC get_or_create_device_assignment - creates device and assignment in PostgreSQL]
    end

    subgraph destD [Destination]
        DD1[(Cloud: telemetry.devices)]
        DD2[(Cloud: telemetry.device_assignments)]
    end

    AD1 --> TD1
    TD1 -->|sent to RPC| PD1
    PD1 --> DD1
    PD1 --> DD2
```

### Bucket F: Lesson Engine – Calibration, Realtime Display, Reassessment, Range Gained

*Full flow: Calibrate (min/max) → Do lesson (green/red) → Reassessment (new max) → Range gained (computed and stored).*

#### Step 1: Calibration (Before Lesson)

*Processing: **Device**. Transaction → Device processes (convertToDegrees) → Cloud.*

| | |
|---|---|
| **Application** | Patient taps "Set Starting Position" while leg is bent ~90°; then taps "Set Maximum Position" while leg is fully extended. |
| **Transaction** | Raw flex sensor value (185–300), stage (starting_position \| maximum_position), device_assignment_id, recorded_at |
| **Processing** | **Device**: Convert raw sensor to degrees via convertToDegrees(); TelemetryService.saveCalibration → insert; invalidate calibration cache |
| **Destination** | Cloud: telemetry.calibrations. Device: cache (calibrationPoints, used when lesson loads) |

#### Step 2: Realtime Display (During Lesson)

*Processing: **Device**. Transaction → Device processes → Screen only (not persisted).*

| | |
|---|---|
| **Application** | Patient moves leg through reps; flex sensor and IMU stream continuously. |
| **Transaction** | Raw flex sensor value, raw IMU value; calibration rest/max degrees (read from step 1); PT-set restSec per lesson |
| **Processing** | **Device**: Every 100ms: convert raw flex to degrees; compare to animation; validate max (10°), pace (25°), IMU (±7); show green or red on screen |
| **Destination** | Screen only (not persisted). Future: Bucket G will store error counts. |

#### Step 3: Reassessment (After Lesson)

*Processing: **Device**. Transaction → Device processes (convertToDegrees) → Cloud.*

| | |
|---|---|
| **Application** | Patient extends leg to max again; taps "Set Maximum Position." |
| **Transaction** | Raw flex sensor value, stage (maximum_position), device_assignment_id, recorded_at |
| **Processing** | **Device**: Convert raw sensor to degrees via convertToDegrees(); TelemetryService.saveCalibration → insert new row; invalidate calibration cache |
| **Destination** | Cloud: telemetry.calibrations. Device: cache invalidated. |

#### Step 4: Range Gained

*Processing: **Device**. Transaction (fetch from cloud) → Device processes (compute difference) → Device cache / Cloud (if stored).*

| | |
|---|---|
| **Application** | Patient views Completion screen; app displays range gained. |
| **Transaction** | Two most recent maximum_position records from telemetry.calibrations (original max from step 1; reassessment max from step 3) |
| **Processing** | **Device**: TelemetryService.getAllMaximumCalibrationsForPatient → compute difference (reassessment max − original max); convert raw to degrees if needed |
| **Destination** | Cloud: rehab.session_metrics.range_of_motion_deg or derived from calibrations. Device: cache for display. |

```mermaid
flowchart TB
    subgraph Calibration ["1. Calibration - Device processes then Cloud"]
        A1[User sets starting position]
        A2[User sets maximum position]
        T1[Transaction: Raw flex 185-300, stage, device_assignment_id, recorded_at]
        P1[Processing Device: convertToDegrees; saveCalibration; invalidate cache]
        D1[Cloud: telemetry.calibrations]
        D2[Device: cache]
        A1 --> T1
        A2 --> T1
        T1 --> P1
        P1 --> D1
        P1 --> D2
    end

    subgraph Realtime ["2. Realtime - Device processes, Screen only"]
        B1[User extends leg up]
        B2[User flexes leg down]
        B3[User keeps or drifts thigh]
        B4[Animation at top - user at max or not]
        T2[Transaction: Raw flex, raw IMU, calibration rest/max, PT restSec]
        P2[Processing Device: Convert to degrees; compare; validate 25 deg 10 deg IMU plus minus 7]
        R1[Green: on pace, centered, max - Display only]
        R2[Red: Speed up, Slow down, Center thigh, Extend - Display only]
        B1 --> T2
        B2 --> T2
        B3 --> T2
        B4 --> T2
        T2 --> P2
        P2 --> R1
        P2 --> R2
    end

    subgraph Reassessment ["3. Reassessment - Device processes then Cloud"]
        C1[User extends to max again]
        C2[User taps Set Maximum Position]
        T3[Transaction: Raw flex, stage maximum_position, device_assignment_id, recorded_at]
        P3[Processing Device: convertToDegrees; saveCalibration; invalidate cache]
        D3[Cloud: telemetry.calibrations]
        D4[Device: cache invalidated]
        C1 --> C2
        C2 --> T3
        T3 --> P3
        P3 --> D3
        P3 --> D4
    end

    subgraph RangeGained ["4. Range Gained - Device processes"]
        T4[Transaction: Two most recent max calibrations]
        P4[Processing Device: Compute difference; convert raw to degrees if needed]
        D5[Cloud: session_metrics or derived]
        D6[Device: cache for display]
        T4 --> P4
        P4 --> D5
        P4 --> D6
    end

    Calibration --> Realtime
    Realtime --> Reassessment
    Reassessment --> RangeGained
```

**Realtime green/red** (during lesson):

| Scenario | Tolerance | Processing | Message |
|----------|-----------|------------|---------|
| On pace | Within 25° of animation | Green | — |
| Too fast | >25° ahead + rate >1.5× expected | Red | "Slow down your movement!" |
| Too slow | >25° behind + rate <0.5× expected | Red | "Speed up your Rep!" |
| Thigh drift | IMU outside ±7 | Red | "Keep your thigh centered" |
| Max not reached | Not within 10° of max when animation hits top | Red | "Extend your leg further!" |

**PT sets rep speed** via restSec (seconds between reps) in each lesson node on the Journey Map.

---

### Bucket 3: Identity and Account Data (incl. PT-Patient Management)

*Processing: **Mixed**. Signup → Cloud (Auth hashes password). Profiles → Device sends raw → Cloud. Patient link → Device trim + Cloud RPC. PT add/delete → Cloud RPC. PT view → Device fetch + cache.*

```mermaid
flowchart TB
    subgraph app3 [Application - User Actions]
        A3A[User signs up / creates account]
        A3B[Patient completes onboarding]
        A3C[PT creates account]
        A3D[Patient links via access code]
        A3E[PT adds patient]
        A3F[PT deletes mapping]
        A3G[PT views patient list or detail]
    end

    subgraph tx3 [Transaction - What is captured]
        T3A[email, password, first_name, last_name, phone, role]
        T3B[profile_id, date_of_birth, gender, surgery_date, phone, allow_notifications, allow_camera, intake_notes]
        T3C[profile_id, practice_name, license_number, npi_number, contact_email, contact_phone]
        T3D[access_code, patient_profile_id]
        T3E[patient_profile_id, pt_profile_id]
        T3F[patient_profile_id, pt_profile_id]
        T3G[pt_profile_id for list; patient_profile_id for detail - query keys]
    end

    subgraph proc3 [Processing]
        P3A[Cloud: Supabase Auth hashes password; create login account]
        P3B[Device sends; Cloud: raw insert]
        P3C[Device sends; Cloud: raw insert]
        P3D[Device: trim access code; Cloud: RPC lookup; trigger generates unique code on patient create]
        P3E[Cloud: RPC link_patient_to_pt or add_patient_with_mapping]
        P3F[Cloud: RPC delete_pt_patient_mapping]
        P3G[Device: Fetch from Supabase; cache list and detail]
    end

    subgraph dest3 [Destination]
        D3A[(Cloud: auth.users)]
        D3B[(Cloud: accounts.profiles)]
        D3C[(Cloud: accounts.patient_profiles)]
        D3D[(Cloud: accounts.pt_profiles)]
        D3E[(Cloud: accounts.pt_patient_map)]
        D3F[Device: cached list and detail]
    end

    A3A --> T3A
    T3A -->|sent to Auth| P3A --> D3A
    T3A --> P3B --> D3B
    A3B --> T3B --> P3B --> D3C
    A3C --> T3C --> P3B --> D3D
    A3D --> T3D --> P3D --> D3E
    A3E --> T3E -->|sent to RPC| P3E --> D3E
    A3F --> T3F -->|sent to RPC| P3F --> D3E
    A3G --> T3G --> P3G --> D3F
```

---

### Bucket 4: Schedule Data

*Processing: **Device**. Transaction → Device processes (parse, compute triggers, schedule notifications) → Cloud + Device.*

```mermaid
flowchart TB
    subgraph app4 [Application - User Actions]
        A4A[Patient selects days and times]
        A4B[Patient taps Confirm Schedule]
        A4C[Patient toggles Allow Reminders]
    end

    subgraph tx4 [Transaction - What is captured]
        T4A[patient_profile_id, day_of_week 0-6, slot_time HH:mm:ss]
        T4B[schedule_reminders_enabled boolean]
    end

    subgraph proc4 [Processing - Device]
        P4A[Replace old slots with new; delete then insert]
        P4B[Update patient_profiles.schedule_reminders_enabled]
        P4C[Parse slot_time; compute T-15 and T triggers for 14-day rolling window; schedule iOS notifications]
    end

    subgraph dest4 [Destination]
        D4A[(Cloud: accounts.patient_schedule_slots)]
        D4B[(Cloud: accounts.patient_profiles)]
        D4C[Device: cached schedule]
        D4D[Device: iOS notification schedule]
    end

    A4A --> T4A
    A4B --> T4A --> P4A --> D4A
    A4B --> T4A --> P4C --> D4C
    A4B --> T4A --> P4C --> D4D
    A4C --> T4B --> P4B --> D4B
```

### Bucket H: Lesson Progress

*Processing: **Device** for draft, restart reset, and queue. **Cloud** when syncing (RPC validates status, upserts).*

```mermaid
flowchart TB
    subgraph appH [Application - User Actions]
        AH1[Patient taps Begin Lesson]
        AH2[Patient completes rep / pauses / leaves]
        AH4[Patient taps Restart Lesson]
        AH3[PT or Patient opens Journey Map]
    end

    subgraph txH [Transaction - What is captured]
        TH1[lesson_id, reps_completed, reps_target, elapsed_seconds, status]
        TH2["lesson_id (restart request)"]
    end

    subgraph procH [Processing]
        PH1[Device: Store draft for offline resume]
        PH2[Device: Queue for upload; when online Cloud: RPC validates status inProgress or completed; upsert]
        PH3[Device: Read from cloud; merge with local draft]
        PH4[Device: Clear local draft; reset progress state]
    end

    subgraph destH [Destination]
        DH1[Device: RealRehabLessonProgress]
        DH2[Device: RealRehabOutbox]
        DH3[(Cloud: accounts.patient_lesson_progress)]
        DH4[Device: cached progress for UI]
        DH5["Device: draft removed (restart)"]
    end

    AH1 --> TH1 --> PH1 --> DH1
    AH2 --> TH1 --> PH1 --> DH1
    AH2 --> TH1 --> PH2 --> DH2
    AH4 --> TH2 --> PH4 --> DH5
    DH2 -->|when online sent to RPC| DH3
    AH3 --> PH3 --> DH3
    AH3 --> PH3 --> DH4
```

### Bucket G: Sensor-Based Raw Insights (During Lesson) – FUTURE

*Processing: **Device**. Transaction → Device processes (detect, increment, aggregate) → Device storage; when online → Cloud.*

*Will persist all events from Bucket F (Lesson Engine) that currently only display on screen.*

```mermaid
flowchart TB
    subgraph appG [Application - Sensor Events]
        AG1[Leg drifts left or right]
        AG2[Did not extend leg far enough]
        AG3[Moving too slow or too fast]
        AG4[Leg shakes or wobbles]
        AG5[Knee goes over toe]
    end

    subgraph txG [Transaction - What is captured]
        TG1[Raw flex, raw IMU; event type when detected: drift, max not reached, speed error, shake, anterior migration]
    end

    subgraph procG [Processing - Device]
        PG1[Check every 100ms; detect event type; increment count; aggregate on rep end or pause]
        PG2[Queue for upload when internet is available]
    end

    subgraph destG [Destination]
        DG1[Device: RealRehabSensorInsights]
        DG2[Device: Outbox]
        DG3[(Cloud: lesson_sensor_insights or quality metrics)]
    end

    AG1 --> TG1
    AG2 --> TG1
    AG3 --> TG1
    AG4 --> TG1
    AG5 --> TG1
    TG1 --> PG1
    PG1 --> DG1
    PG1 --> PG2 --> DG2
    DG2 -->|when online| DG3
```

---

## 5. Replication Instructions

To recreate these diagrams in your preferred tool (e.g., Figma, Lucidchart, draw.io):

1. **Render Mermaid**: Use [mermaid.live](https://mermaid.live), GitHub, or VS Code (Mermaid extension) to view the diagrams.
2. **Export**: From Mermaid Live Editor, export as PNG or SVG.
3. **Manual recreation**: Each subgraph maps to a swimlane or container. Nodes are boxes; arrows show flow. Order: Application → Transaction (what is captured) → Processing (raw kept or transformed) → Destination (where it goes).
4. **Color coding**: Consider using distinct colors for Application (blue), Transaction (yellow), and Destination (green) for clarity.
