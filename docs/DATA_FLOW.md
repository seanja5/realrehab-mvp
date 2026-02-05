# RealRehab Data Flow Documentation

Comprehensive data flow analysis and visual documentation for the RealRehab app. Organizes all data into buckets, identifies the top 3 most impactful modules, and shows Application (user action) → Processing → Transaction (data) → Destination (Supabase vs local storage).

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

### Bucket A: Identity and Account Data

- **Tables**: profiles, patient_profiles, pt_profiles, pt_patient_map
- **Data**: email, password, role, first_name, last_name, phone, DOB, gender, surgery_date, access_code, practice_name, license_number, NPI, etc.
- **Flow**: Sign up → Supabase Auth + profiles; Create account → patient_profiles/pt_profiles; Link PT → pt_patient_map (RPC); Add patient → pt_patient_map (RPC)
- **Storage**: Supabase only (no local-first for identity)

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

### Bucket E: PT-Patient Management

- **Tables**: pt_patient_map, patient_profiles (for list/detail)
- **Data**: Patient list (name, profile info), patient detail, mapping status
- **Flow**: PT adds patient (RPC), deletes mapping; PT views list/detail → Supabase → Cache
- **Storage**: Supabase; Cache for list/detail

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

For each bucket, the diagram uses four subgraphs:

- **Application**: What the user or sensor does (e.g., "Patient taps Begin Lesson", "PT saves plan")
- **Processing**: What the app does with that action (e.g., "Save plan and replace old one", "Store progress on device so it's not lost offline")
- **Transaction**: What information is captured or sent (e.g., "Plan details: patient, injury type, lessons", "Reps done, reps goal, time spent")
- **Destination**: Where it goes (cloud database or device storage)

### Bucket B: PT Creates Rehab Plan

```mermaid
flowchart TB
    subgraph appB [Application - User Actions]
        AB1[PT selects patient]
        AB2[PT builds journey map: Knee/ACL, phases, lesson order]
        AB3[PT sets lesson types and parameters per node]
        AB4[PT taps Confirm Journey]
    end

    subgraph procB [Processing]
        PB1[Archive existing active plan for patient]
        PB2[Convert LessonNode to PlanNodeDTO; encode JSONB; hardcode category=Knee injury=ACL; trim notes]
        PB3[Invalidate plan cache]
    end

    subgraph txB [Transaction - What is captured]
        TB1[Plan metadata: category, injury, status, notes]
        TB2[Lesson nodes: order, nodeType, phase, reps, restSec, sets, restBetweenSets, kneeBendAngle, timeHoldingPosition, title, icon, isLocked]
    end

    subgraph destB [Destination]
        DB1[(Cloud: accounts.rehab_plans)]
        DB2[Device: cached plan for UI]
    end

    AB1 --> AB2 --> AB3 --> AB4
    AB4 --> PB1 --> PB2 --> TB1
    PB2 --> TB2
    TB1 --> DB1
    TB2 --> DB1
    PB3 --> DB2
```

### Bucket D: Device Pairing

```mermaid
flowchart TB
    subgraph appD [Application - User Actions]
        AD1[Patient pairs BLE knee brace]
    end

    subgraph procD [Processing]
        PD1[RPC get_or_create_device_assignment]
    end

    subgraph txD [Transaction - What is captured]
        TD1[bluetooth_identifier]
        TD2[device_id, patient_profile_id, pt_profile_id]
    end

    subgraph destD [Destination]
        DD1[(Cloud: telemetry.devices)]
        DD2[(Cloud: telemetry.device_assignments)]
    end

    AD1 --> TD1 --> PD1 --> TD2
    PD1 --> DD1
    PD1 --> DD2
```

### Bucket F: Lesson Engine – Calibration, Realtime Display, Reassessment, Range Gained

*Full flow: Calibrate (min/max) → Do lesson (green/red) → Reassessment (new max) → Range gained (computed and stored).*

#### Step 1: Calibration (Before Lesson)

| | |
|---|---|
| **Application** | Patient taps "Set Starting Position" while leg is bent ~90°; then taps "Set Maximum Position" while leg is fully extended. |
| **Transaction** | Raw flex sensor value (185–300) → convertToDegrees() → flex_value (degrees), stage, knee_angle_deg, recorded_at |
| **Processing** | Convert raw sensor to degrees; TelemetryService.saveCalibration → insert into telemetry.calibrations; invalidate calibration cache |
| **Destination** | Cloud: telemetry.calibrations. Device: cache (calibrationPoints, used when lesson loads) |

#### Step 2: Realtime Display (During Lesson)

| | |
|---|---|
| **Application** | Patient moves leg through reps; flex sensor and IMU stream continuously. |
| **Transaction** | Raw flex sensor value, raw IMU value; calibration rest/max degrees (read from step 1) |
| **Processing** | Every 100ms: convert flex to degrees using calibration; compare to animation expected position; validate max reached (10°), movement speed (25°), IMU center (±7); show green or red on screen |
| **Destination** | Screen only (not persisted). Future: Bucket G will store error counts. |

#### Step 3: Reassessment (After Lesson)

| | |
|---|---|
| **Application** | Patient extends leg to max again; taps "Set Maximum Position." |
| **Transaction** | Raw flex sensor value → convertToDegrees() → flex_value (degrees), stage (maximum_position), recorded_at |
| **Processing** | Convert raw sensor to degrees; TelemetryService.saveCalibration → insert new row into telemetry.calibrations; invalidate calibration cache |
| **Destination** | Cloud: telemetry.calibrations. Device: cache invalidated. |

#### Step 4: Range Gained

| | |
|---|---|
| **Application** | Patient views Completion screen; app displays range gained. |
| **Transaction** | Original max (from step 1 calibration); reassessment max (from step 3) |
| **Processing** | TelemetryService.getAllMaximumCalibrationsForPatient → take two most recent maximum_position records → compute difference (reassessment max − original max) |
| **Destination** | Cloud: rehab.session_metrics.range_of_motion_deg or derived from calibrations. Device: cache for display. |

```mermaid
flowchart TB
    subgraph Calibration ["1. Calibration - Before Lesson"]
        A1[User sets starting position]
        A2[User sets maximum position]
        T1[Raw flex - convertToDegrees - stage, flex_value degrees, knee_angle_deg]
        P1[Processing: Convert raw to degrees; saveCalibration]
        D1[Cloud: telemetry.calibrations]
        D2[Device: cache]
        A1 --> T1
        A2 --> T1
        T1 --> P1
        P1 --> D1
        P1 --> D2
    end

    subgraph Realtime ["2. Realtime Lesson - During"]
        B1[User extends leg up]
        B2[User flexes leg down]
        B3[User keeps or drifts thigh]
        B4[Animation at top - user at max or not]
        T2[Transaction: Raw flex, IMU, calibration rest/max, PT restSec]
        P2[Processing: Convert to degrees, compare to animation, check 25 deg, 10 deg max, IMU plus minus 7]
        R1[Green: on pace, centered, max reached - Display only]
        R2[Red: Speed up, Slow down, Center thigh, Extend further - Display only]
        B1 --> T2
        B2 --> T2
        B3 --> T2
        B4 --> T2
        T2 --> P2
        P2 --> R1
        P2 --> R2
    end

    subgraph Reassessment ["3. Reassessment - After Lesson"]
        C1[User extends to max again]
        C2[User taps Set Maximum Position]
        T3[Raw flex - convertToDegrees - New max flex_value degrees]
        P3[Processing: Convert raw to degrees; saveCalibration]
        D3[Cloud: telemetry.calibrations]
        D4[Device: cache invalidated]
        C1 --> C2
        C2 --> T3
        T3 --> P3
        P3 --> D3
        P3 --> D4
    end

    subgraph RangeGained ["4. Range Gained"]
        T4[Transaction: Original max, Reassessment max]
        P4[Processing: Compute difference]
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

### Bucket 3: Identity and Account Data

```mermaid
flowchart TB
    subgraph app3 [Application - User Actions]
        A3A[User signs up / creates account]
        A3B[Patient completes onboarding]
        A3C[PT creates account]
        A3D[Patient links via access code]
        A3E[PT adds patient]
    end

    subgraph proc3 [Processing]
        P3A[Create secure login account - password hashed by Supabase Auth]
        P3B[Create or update user profile]
        P3C[Save patient or PT info]
        P3D[Trim access code; RPC lookup; DB generates unique code on patient create]
    end

    subgraph tx3 [Transaction - What is captured]
        T3A[Login info: email, password, name]
        T3B[Patient info: DOB, gender, surgery date, phone]
        T3C[PT info: practice name, license, NPI]
        T3D[Access code - normalized; patient-PT link]
        T3E[Patient and PT link]
    end

    subgraph dest3 [Destination]
        D3A[(Cloud: login accounts)]
        D3B[(Cloud: user profiles)]
        D3C[(Cloud: patient profiles)]
        D3D[(Cloud: PT profiles)]
        D3E[(Cloud: patient-PT links)]
    end

    A3A --> P3A --> T3A --> D3A
    A3A --> P3B --> T3A --> D3B
    A3B --> P3C --> T3B --> D3C
    A3C --> P3C --> T3C --> D3D
    A3D --> P3D --> T3D --> D3E
    A3E --> P3D --> T3E --> D3E
```

### Bucket E: PT-Patient Management

```mermaid
flowchart TB
    subgraph appE [Application - User Actions]
        AE1[PT adds patient via RPC]
        AE2[PT deletes mapping]
        AE3[PT views patient list or detail]
    end

    subgraph procE [Processing]
        PE1[RPC link_patient_to_pt or add patient]
        PE2[RPC delete mapping]
        PE3[Fetch from Supabase; cache list and detail]
    end

    subgraph txE [Transaction - What is captured]
        TE1[patient_profile_id, pt_profile_id]
        TE2[Patient list, patient detail, mapping status]
    end

    subgraph destE [Destination]
        DE1[(Cloud: pt_patient_map)]
        DE2[Device: cached list and detail]
    end

    AE1 --> TE1 --> PE1 --> DE1
    AE2 --> PE2 --> DE1
    AE3 --> PE3 --> TE2 --> DE2
```

---

### Bucket 4: Schedule Data

```mermaid
flowchart TB
    subgraph app4 [Application - User Actions]
        A4A[Patient selects days and times]
        A4B[Patient taps Confirm Schedule]
        A4C[Patient toggles Allow Reminders]
    end

    subgraph proc4 [Processing]
        P4A[Replace old schedule with new selected times]
        P4B[Update reminder preference]
        P4C[Parse slot_time HH:mm:ss; compute T-15 and T triggers for 14-day rolling window]
    end

    subgraph tx4 [Transaction - What is captured]
        T4A[Selected days and 30-min time slots]
        T4B[Whether reminders are on or off]
    end

    subgraph dest4 [Destination]
        D4A[(Cloud: schedule slots)]
        D4B[(Cloud: reminder preference)]
        D4C[Device: cached schedule]
        D4D[Device: notification schedule]
    end

    A4A --> T4A
    A4B --> P4A --> T4A --> D4A
    A4B --> P4C --> T4A --> D4C
    A4B --> P4C --> T4A --> D4D
    A4C --> P4B --> T4B --> D4B
```

### Bucket H: Lesson Progress

```mermaid
flowchart TB
    subgraph appH [Application - User Actions]
        AH1[Patient taps Begin Lesson]
        AH2[Patient completes rep / pauses / leaves]
        AH3[PT or Patient opens Journey Map]
    end

    subgraph procH [Processing]
        PH1[Store progress on device so it is not lost if offline]
        PH2[Queue for upload; RPC validates status inProgress or completed when syncing]
        PH3[Read progress from cloud and merge with local draft]
    end

    subgraph txH [Transaction - What is captured]
        TH1[lesson_id, reps_completed, reps_target, elapsed_seconds, status]
    end

    subgraph destH [Destination]
        DH1[Device: RealRehabLessonProgress draft file]
        DH2[Device: RealRehabOutbox upload queue]
        DH3[(Cloud: accounts.patient_lesson_progress)]
        DH4[Device: cached progress for UI]
    end

    AH1 --> PH1 --> TH1 --> DH1
    AH2 --> PH1 --> TH1 --> DH1
    AH2 --> PH2 --> TH1 --> DH2
    DH2 -->|when online| DH3
    AH3 --> PH3 --> DH3
    AH3 --> DH4
```

### Bucket G: Sensor-Based Raw Insights (During Lesson) – FUTURE

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

    subgraph procG [Processing]
        PG1[Check movement quality every tenth of a second]
        PG2[Detect leg instability]
        PG3[Add up error counts when rep ends or lesson pauses]
        PG4[Queue for upload when internet is available]
    end

    subgraph txG [Transaction - What is captured]
        TG1[Times leg drifted left or right]
        TG2[Reps not completed fully, too slow, too fast]
        TG3[Times leg shook, knee over toe]
        TG4[Rep duration, time spent in error]
    end

    subgraph destG [Destination]
        DG1[Device: sensor insights file]
        DG2[Device: upload queue]
        DG3[(Cloud: quality metrics)]
        DG4[(Cloud: stability metrics)]
        DG5[(Cloud: biomechanics metrics)]
    end

    AG1 --> PG1
    AG2 --> PG1
    AG3 --> PG1
    AG4 --> PG2
    AG5 --> PG1
    PG1 --> PG3
    PG2 --> PG3
    PG3 --> TG1
    PG3 --> TG2
    PG3 --> TG3
    PG3 --> TG4
    TG1 --> DG1
    TG2 --> DG1
    TG3 --> DG1
    TG4 --> DG1
    PG4 --> DG2
    DG1 --> DG2
    DG2 -->|when online| DG3
    DG2 -->|when online| DG4
    DG2 -->|when online| DG5
```

---

## 5. Replication Instructions

To recreate these diagrams in your preferred tool (e.g., Figma, Lucidchart, draw.io):

1. **Render Mermaid**: Use [mermaid.live](https://mermaid.live), GitHub, or VS Code (Mermaid extension) to view the diagrams.
2. **Export**: From Mermaid Live Editor, export as PNG or SVG.
3. **Manual recreation**: Each subgraph maps to a swimlane or container. Nodes are boxes; arrows show flow. Use plain-language labels: Application (what the user does), Processing (what the app does), Transaction (what is captured), Destination (where it goes).
4. **Color coding**: Consider using distinct colors for Application (blue), Transaction (yellow), and Destination (green) for clarity.
