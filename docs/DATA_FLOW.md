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

### Bucket B: Rehab Plan and Lesson Progress

- **Tables**: accounts.rehab_plans, accounts.patient_lesson_progress
- **Data**: Plan nodes (id, title, icon, isLocked, reps, restSec, nodeType, phase), notes; Lesson progress (reps_completed, reps_target, elapsed_seconds, status)
- **Flow**: PT creates/edits plan → Supabase rehab_plans; Patient does lesson → LocalLessonProgressStore (disk) → OutboxSyncManager (disk) → RPC upsert when online → Supabase patient_lesson_progress; PT/Patient views journey map → Supabase → Cache → UI
- **Storage**: Local-first for lesson progress (draft + outbox); Cloud for plans and synced progress

### Bucket C: Schedule Data

- **Tables**: patient_schedule_slots, patient_profiles.schedule_reminders_enabled
- **Data**: day_of_week (0-6), slot_time (HH:mm:ss), boolean for reminders
- **Flow**: Patient sets schedule → Supabase patient_schedule_slots; Toggle reminders → Supabase patient_profiles; NotificationManager schedules local notifications from slots
- **Storage**: Supabase; Cache for UI; Notifications stored locally by iOS

### Bucket D: Device and Calibration Data

- **Tables**: telemetry.devices, telemetry.device_assignments, telemetry.calibrations
- **Data**: bluetooth_identifier, stage (starting_position/maximum_position), flex_value, knee_angle_deg
- **Flow**: Pair device → RPC get_or_create_device_assignment; Calibrate → Supabase calibrations; Used by LessonView for degree conversion
- **Storage**: Supabase only

### Bucket E: PT-Patient Management

- **Tables**: pt_patient_map, patient_profiles (for list/detail)
- **Data**: Patient list (name, profile info), patient detail, mapping status
- **Flow**: PT adds patient (RPC), deletes mapping; PT views list/detail → Supabase → Cache
- **Storage**: Supabase; Cache for list/detail

### Bucket F: Sensor-Based Raw Insights (During Lesson) – FUTURE

- **Tables**: accounts.lesson_sensor_insights (or lesson_quality_metrics, lesson_stability_metrics, lesson_biomechanics_metrics)
- **Data**: valgus_left_count, valgus_right_count, max_not_reached_count, speed_too_slow_count, speed_too_fast_count, shake_count, anterior_migration_count; optional: rep_duration, time_in_error_seconds, max_extension_achieved_per_rep, peak_imu_deviation_per_rep
- **Flow**: Sensor event → LessonView validation increments counter → Local file (RealRehabSensorInsights) + Outbox → RPC when online → Supabase; PT views via dashboard
- **Storage**: Local-first (RealRehabSensorInsights, Outbox); Supabase when synced

---

## 3. Top 3 Most Impactful Buckets

| Rank | Bucket                             | Rationale                                                                                                                                                                                         |
| ---- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | **Rehab Plan and Lesson Progress** | Core product flow. Most complex: local-first lesson draft, outbox sync, RPC upsert, bidirectional PT/patient views. Highest data volume during lessons (reps, elapsed, status every rep + timer). |
| 2    | **Identity and Account Data**      | Foundation for all flows. Auth, profiles, PT-patient linking. Every user touches this on signup, login, and profile/link actions.                                                                 |
| 3    | **Schedule Data**                  | Patient engagement driver. Schedule slots + reminders affect NotificationManager and "My Schedule" visualizer. Clear flow: patient sets → Supabase → cache → notifications.                       |

---

## 4. Data Flow Diagrams

For each bucket, the diagram uses four subgraphs:

- **Application**: User/sensor action (e.g., "Patient starts lesson", "PT saves rehab plan")
- **Processing**: App logic that validates, aggregates, or transforms raw inputs into the transaction payload (e.g., RehabService.saveACLPlan archives/inserts; LocalLessonProgressStore persists; OutboxSyncManager encodes)
- **Transaction**: Specific data fields being sent
- **Destination**: Supabase (table/RPC) or Local (disk path)

### Bucket 1: Rehab Plan and Lesson Progress

```mermaid
flowchart TB
    subgraph app1 [Application - User Actions]
        A1A[PT creates/edits plan in Journey Map]
        A1B[PT taps Confirm Journey]
        A1C[Patient taps Begin Lesson]
        A1D[Patient completes rep / pauses / leaves]
        A1E[PT opens patient Journey Map]
        A1F[Patient opens Journey Map]
    end

    subgraph proc1 [Processing]
        P1A[RehabService.saveACLPlan archives old, inserts new]
        P1B[LocalLessonProgressStore persists draft to disk]
        P1C[OutboxSyncManager encodes payload]
    end

    subgraph tx1 [Transaction - Data]
        T1A[pt_profile_id, patient_profile_id, category, injury, status, nodes JSON, notes]
        T1B[lesson_id, reps_completed, reps_target, elapsed_seconds, status]
        T1C[Same as T1B - from local draft]
    end

    subgraph dest1 [Destination]
        D1A[(Supabase: accounts.rehab_plans)]
        D1B[(Supabase: patient_lesson_progress via RPC)]
        D1C[Local: RealRehabLessonProgress/lessonId.json]
        D1D[Local: RealRehabOutbox/outbox.json]
        D1E[Local: Cache lessonProgress]
    end

    A1A --> P1A --> T1A
    A1B --> P1A --> T1A --> D1A
    A1C --> P1B --> T1B --> D1C
    A1D --> P1B --> T1B --> D1C
    A1D --> P1C --> T1C --> D1D
    D1D -->|when online| D1B
    A1E --> D1B
    A1E --> D1E
    A1F --> D1B
    A1F --> D1E
```

### Bucket 2: Identity and Account Data

```mermaid
flowchart TB
    subgraph app2 [Application - User Actions]
        A2A[User signs up / creates account]
        A2B[Patient completes onboarding]
        A2C[PT creates account]
        A2D[Patient links via access code]
        A2E[PT adds patient]
    end

    subgraph proc2 [Processing]
        P2A[Supabase Auth creates auth.users]
        P2B[AuthService.ensureProfile upserts profiles]
        P2C[PatientService/PTService upsert profiles]
        P2D[RPCs bypass RLS for secure linking]
    end

    subgraph tx2 [Transaction - Data]
        T2A[email, password, role, first_name, last_name]
        T2B[profile_id, date_of_birth, gender, surgery_date, phone]
        T2C[profile_id, practice_name, license_number, NPI, etc.]
        T2D[access_code, patient_profile_id]
        T2E[patient_profile_id, pt_profile_id]
    end

    subgraph dest2 [Destination]
        D2A[(Supabase Auth)]
        D2B[(Supabase: accounts.profiles)]
        D2C[(Supabase: accounts.patient_profiles)]
        D2D[(Supabase: accounts.pt_profiles)]
        D2E[(Supabase: pt_patient_map via RPC)]
    end

    A2A --> P2A --> T2A --> D2A
    A2A --> P2B --> T2A --> D2B
    A2B --> P2C --> T2B --> D2C
    A2C --> P2C --> T2C --> D2D
    A2D --> P2D --> T2D --> D2E
    A2E --> P2D --> T2E --> D2E
```

### Bucket 3: Schedule Data

```mermaid
flowchart TB
    subgraph app3 [Application - User Actions]
        A3A[Patient selects days and times]
        A3B[Patient taps Confirm Schedule]
        A3C[Patient toggles Allow Reminders]
    end

    subgraph proc3 [Processing]
        P3A[ScheduleService replace slots delete plus insert]
        P3B[PatientService.setScheduleRemindersEnabled updates]
        P3C[NotificationManager schedules local notifications]
    end

    subgraph tx3 [Transaction - Data]
        T3A[day_of_week, slot_time for each 30-min block]
        T3B[schedule_reminders_enabled boolean]
    end

    subgraph dest3 [Destination]
        D3A[(Supabase: patient_schedule_slots)]
        D3B[(Supabase: patient_profiles.schedule_reminders_enabled)]
        D3C[Local: Cache patientSchedule]
        D3D[Local: iOS NotificationManager]
    end

    A3A --> T3A
    A3B --> P3A --> T3A --> D3A
    A3B --> P3C --> T3A --> D3C
    A3B --> P3C --> T3A --> D3D
    A3C --> P3B --> T3B --> D3B
```

### Bucket F: Sensor-Based Raw Insights (During Lesson) – FUTURE

```mermaid
flowchart TB
    subgraph appF [Application - Sensor Events]
        AF1[IMU lateral drift left or right]
        AF2[Flex - max not reached]
        AF3[Flex plus time - too slow or too fast]
        AF4[Flex or IMU - shake detected]
        AF5[IMU or camera - anterior migration]
    end

    subgraph procF [Processing]
        PF1[LessonView validation every 100ms]
        PF2[Shake detection 200ms sliding window]
        PF3[Counter aggregation on rep pause complete]
        PF4[Payload encoding enqueue to Outbox]
    end

    subgraph txF [Transaction - Data]
        TF1[valgus_left_count, valgus_right_count]
        TF2[max_not_reached_count, speed_too_slow_count, speed_too_fast_count]
        TF3[shake_count, anterior_migration_count]
        TF4[Optional: rep_duration, time_in_error_seconds]
    end

    subgraph destF [Destination]
        DF1[Local: RealRehabSensorInsights/lessonId.json]
        DF2[Local: RealRehabOutbox/outbox.json]
        DF3[(Supabase: lesson_sensor_insights via RPC)]
    end

    AF1 --> PF1
    AF2 --> PF1
    AF3 --> PF1
    AF4 --> PF2
    AF5 --> PF1
    PF1 --> PF3
    PF2 --> PF3
    PF3 --> TF1
    PF3 --> TF2
    PF3 --> TF3
    PF3 --> TF4
    TF1 --> DF1
    TF2 --> DF1
    TF3 --> DF1
    TF4 --> DF1
    PF4 --> DF2
    DF1 --> DF2
    DF2 -->|when online| DF3
```

---

## 5. Replication Instructions

To recreate these diagrams in your preferred tool (e.g., Figma, Lucidchart, draw.io):

1. **Render Mermaid**: Use [mermaid.live](https://mermaid.live), GitHub, or VS Code (Mermaid extension) to view the diagrams.
2. **Export**: From Mermaid Live Editor, export as PNG or SVG.
3. **Manual recreation**: Each subgraph maps to a swimlane or container. Nodes are boxes; arrows show flow. Use the same labels for Application, Processing, Transaction, and Destination sections.
4. **Color coding**: Consider using distinct colors for Application (blue), Transaction (yellow), and Destination (green) for clarity.
