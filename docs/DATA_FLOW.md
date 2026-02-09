# RealRehab Data Flow Documentation

Comprehensive data flow analysis and visual documentation for the RealRehab app. One unified end-to-end flow in user journey order. Each step shows: Application (user action) → Transaction (what is captured) → Processing (where and how) → Pull (from Supabase or cache, if any) → Storage (where data is written, if any).

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
| content   | plan_templates                 | category, injury, nodes (JSONB)                                                                                                            | RehabService (fetchDefaultPlan)       |
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

From [CacheKey.swift](../RealRehabPractice/Services/Cache/CacheKey.swift): patientProfile, patientEmail, hasPT, ptProfile, ptInfo, ptProfileIdFromPatient, rehabPlan, patientList, patientDetail, activeAssignment, program, lessons, authProfile, patientProfileId, patientSchedule, scheduleRemindersEnabled, calibrationPoints, lessonProgress, plan, resolvedSession, defaultPlanTemplate.

---

## 2. End-to-End Data Flow (User Journey Order)

One unified flow in the order of the user journey. **Flow direction**: left to right, driven by user actions. **Structure**: User actions (App) appear in the center; data pulled from storage or cache appears above the action that triggers it; data written (Tx → Proc → Storage) appears below. **Labels**: App (User Action), Tx (Data Transaction), Proc (Processing – Cloud or Device), Storage. Modules are sequential user steps; no arrow connects Module 1 to Module 2.

### Data Flow Cost Minimization

To reduce Supabase reads and writes: **cache-first** for reads (plan, profile, lesson progress, auth profile); **plan templates** fetched once per category/injury and cached; **lesson progress** queued in Outbox and synced when online (batch rather than per-rep). Local draft for offline resume. This keeps Supabase costs low while supporting offline and responsive UI.

---

### Single Unified Flowchart

Each module flows **left to right**, driven by user actions in the center. **Pulls** appear above the action that triggers them; **writes** (Tx → Proc → Storage) appear below. Labels: App (User Action), Tx (Data Transaction), Proc (Processing – Cloud or Device), Storage.

```mermaid
flowchart LR
    subgraph M1 [Module 1: PT Creates Account, Links Patient, Creates Rehab Plan]
        direction LR
        subgraph M1Step1 [PT Creates Account]
            direction TB
            M1A1[App: PT taps Create Account, enters email, password, license, NPI, submits]
            M1T1[Tx: email, password, first_name, last_name, role, license_number, npi_number]
            M1P1[Proc: Cloud - Auth hashes password; profiles upsert; pt_profiles upsert]
            M1St1[(Storage: auth.users, accounts.profiles, accounts.pt_profiles)]
            M1A1 --> M1T1 --> M1P1 --> M1St1
        end
        subgraph M1Step2 [PT Adds Patient]
            direction TB
            M1A2[App: PT taps Add Patient, enters firstName, lastName, DOB, gender, submits]
            M1T2[Tx: firstName, lastName, dob, gender, pt_profile_id]
            M1P2[Proc: Cloud - RPC add_patient_with_mapping]
            M1St2[(Storage: accounts.patient_profiles, accounts.pt_patient_map)]
            M1A2 --> M1T2 --> M1P2 --> M1St2
        end
        subgraph M1Step3 [PT Loads Default Plan]
            direction TB
            M1Pull1[Pull: Supabase content.plan_templates via fetchDefaultPlan - cache first]
            M1A3[App: PT selects patient, CategorySelect Knee, InjurySelect ACL, taps Create Rehab Plan]
            M1P3[Proc: Device - PlanNodeDTO to LessonNode, layoutNodesZigZag]
            M1Pull1 --> M1A3 --> M1P3
        end
        subgraph M1Step4 [PT Edits and Saves Plan]
            direction TB
            M1A4[App: PT views default ACL plan, edits nodes, taps Confirm Journey]
            M1T3[Tx: plan metadata, nodes JSONB]
            M1P4[Proc: Device - archive existing plan, LessonNode to PlanNodeDTO]
            M1St4[(Storage: accounts.rehab_plans)]
            M1A4 --> M1T3 --> M1P4 --> M1St4
        end
        M1Step1 --> M1Step2 --> M1Step3 --> M1Step4
    end

    subgraph M2 [Module 2: Patient Creates Account - Route A With Access Code]
        direction LR
        subgraph M2S1 [Patient Signs Up With Code]
            direction TB
            M2Pull1[Pull: RPC findPatientByAccessCode - lookup placeholder]
            M2A1[App: Patient signs up with DOB, gender, 8-digit access code, submits]
            M2T1[Tx: email, password, first_name, last_name, dob, gender, access_code]
            M2P1[Proc: Cloud - Auth; Device - trim code; Cloud - ensurePatientProfile]
            M2S1A[(Storage: auth.users, profiles, patient_profiles, pt_patient_map)]
            M2Pull1 --> M2A1 --> M2T1 --> M2P1 --> M2S1A
        end
    end

    subgraph M2B [Module 2: Route B - Patient Signs Up, Links PT Later]
        direction LR
        subgraph M2BS1 [Patient Signs Up]
            direction TB
            M2BA1[App: Patient signs up without access code, submits]
            M2BT1[Tx: email, password, first_name, last_name, dob, gender]
            M2BP1[Proc: Cloud - Auth; Cloud - profiles, patient_profiles upsert]
            M2BS1A[(Storage: auth.users, profiles, patient_profiles)]
            M2BA1 --> M2BT1 --> M2BP1 --> M2BS1A
        end
        subgraph M2BS2 [Patient Links PT in Settings]
            direction TB
            M2BPull[Pull: RPC lookup PT by access code]
            M2BA2[App: Patient goes to Settings, taps Connect, enters access code]
            M2BT2[Tx: access_code, patient_profile_id]
            M2BP2[Proc: Device - trim; Cloud - RPC link_patient_via_access_code]
            M2BS2A[(Storage: accounts.pt_patient_map)]
            M2BPull --> M2BA2 --> M2BT2 --> M2BP2 --> M2BS2A
        end
        M2BS1 --> M2BS2
    end

    subgraph M3 [Module 3: Patient Views Rehab Plan]
        direction LR
        subgraph M3S1 [View Journey Map]
            direction TB
            M3Pull1[Pull: myProfile, myPatientProfileId, getPTProfileId from cache or Supabase]
            M3Pull2[Pull: currentPlan, getLessonProgress from cache or Supabase]
            M3A1[App: Patient opens Dashboard or Journey tab]
            M3P1[Proc: Device - merge local draft with remote, display journey map]
            M3Pull1 --> M3Pull2 --> M3A1 --> M3P1
        end
    end

    subgraph M4 [Module 4: Device Pairing]
        direction LR
        subgraph M4S1 [Pair Device]
            direction TB
            M4A1[App: Patient taps Add, Pair Device, selects BLE knee brace]
            M4T1[Tx: bluetooth_identifier serial]
            M4P1[Proc: Cloud - RPC get_or_create_device_assignment]
            M4S1A[(Storage: telemetry.devices, telemetry.device_assignments)]
            M4A1 --> M4T1 --> M4P1 --> M4S1A
        end
    end

    subgraph M5 [Module 5: Calibration]
        direction LR
        subgraph M5S1 [Set Start and Max Position]
            direction TB
            M5A1[App: Patient taps Set Starting Position, then Set Maximum Position]
            M5T1[Tx: raw flex value, stage, device_assignment_id, recorded_at]
            M5P1[Proc: Device - convert to degrees; save calibration]
            M5S1A[(Storage: telemetry.calibrations)]
            M5A1 --> M5T1 --> M5P1 --> M5S1A
        end
    end

    subgraph M6 [Module 6: Knee Extension Exercise]
        direction LR
        subgraph M6S1 [Start Lesson]
            direction TB
            M6Pull1[Pull: calibration from cache or Supabase]
            M6Pull2[Pull: plan nodes from currentPlan cache or Supabase]
            M6A1[App: Patient taps lesson node, Directions, Begin Lesson]
            M6P1[Proc: Device - load calibration and plan for lesson]
            M6Pull1 --> M6Pull2 --> M6A1 --> M6P1
        end
        subgraph M6S2 [During Lesson]
            direction TB
            M6A2[App: Patient moves leg through reps; completes or pauses]
            M6T1[Tx: reps_completed, reps_target, elapsed_seconds, status]
            M6P2[Proc: Device - save draft; validate; green or red on screen]
            M6S2A[Storage: LocalLessonProgressStore draft; Outbox; patient_lesson_progress when online]
            M6A2 --> M6T1 --> M6P2 --> M6S2A
        end
        M6S1 --> M6S2
    end

    subgraph M7 [Module 7: Reassessment After Lesson]
        direction LR
        subgraph M7S1 [Set New Maximum]
            direction TB
            M7A1[App: Patient extends to max again, taps Set Maximum Position]
            M7T1[Tx: raw flex, stage maximum_position, device_assignment_id]
            M7P1[Proc: Device - convert to degrees; save calibration]
            M7S1A[(Storage: telemetry.calibrations)]
            M7A1 --> M7T1 --> M7P1 --> M7S1A
        end
    end

    subgraph M8 [Module 8: Range Gained Completion]
        direction LR
        subgraph M8S1 [View Completion]
            direction TB
            M8Pull1[Pull: max calibrations from Supabase telemetry.calibrations]
            M8A1[App: Patient views Completion screen]
            M8P1[Proc: Device - compute reassessment max minus original max]
            M8S1A[Display: range gained on screen]
            M8Pull1 --> M8A1 --> M8P1 --> M8S1A
        end
    end
```

---

### Module Detail Tables

For each module, the table below summarizes Application, Transaction, Processing, Pull, and Storage.

| Module | Application | Transaction | Pull | Processing | Storage |
|--------|-------------|-------------|------|------------|---------|
| **1a. PT Creates Account** | PT signs up (email, password, license, NPI) | email, password, first_name, last_name, role, license_number, npi_number | None | Cloud: Auth hashes password; profiles upsert; pt_profiles upsert | auth.users, accounts.profiles, accounts.pt_profiles |
| **1b. PT Adds Patient** | PT taps Add Patient, enters name, DOB, gender | firstName, lastName, dob, gender, pt_profile_id | None | Cloud: RPC add_patient_with_mapping | accounts.patient_profiles, accounts.pt_patient_map |
| **1c. PT Creates Rehab Plan (new)** | PT selects patient → CategorySelect → InjurySelect → PTJourneyMapView | — | Supabase content.plan_templates (category=Knee, injury=ACL); cache first | Device: PlanNodeDTO → LessonNode, layoutNodesZigZag | None for load |
| **1c. PT Saves Rehab Plan** | PT edits nodes, taps Confirm Journey | plan metadata, nodes JSONB | Edit flow: rehab_plans, patient_lesson_progress | Device: archive existing plan, LessonNode → PlanNodeDTO | accounts.rehab_plans |
| **2a. Patient With Access Code** | Patient signs up with DOB, gender, 8-digit access code | email, password, first_name, last_name, dob, gender, access_code | RPC findPatientByAccessCode | Cloud: Auth; Device: trim; Cloud: ensurePatientProfile | auth.users, profiles, patient_profiles, pt_patient_map |
| **2b. Patient Without, Link Later** | Patient signs up; later Settings → Connect, enters code | access_code, patient_profile_id | RPC lookup PT by code | Device: trim; Cloud: RPC link_patient_via_access_code | accounts.pt_patient_map |
| **3. Patient Views Plan** | Patient opens Dashboard or Journey tab | — | myProfile, myPatientProfileId, getPTProfileId, currentPlan, getLessonProgress (cache or Supabase) | Device: merge local draft with remote | None |
| **4. Device Pairing** | Patient pairs BLE knee brace | bluetooth_identifier | None | Cloud: RPC get_or_create_device_assignment | telemetry.devices, telemetry.device_assignments |
| **5. Calibration** | Patient taps Set Starting Position, Set Maximum Position | raw flex, stage, device_assignment_id, recorded_at | None for save | Device: convertToDegrees; saveCalibration | telemetry.calibrations; cache calibrationPoints |
| **6. Lesson** | Patient does lesson; reps/pause/complete | reps_completed, reps_target, elapsed_seconds, status | Calibration, plan nodes (cache or Supabase) | Device: convert, validate, green/red; LocalLessonProgressStore; Outbox | RealRehabLessonProgress; Outbox; patient_lesson_progress when online |
| **7. Reassessment** | Patient extends to max, taps Set Maximum Position | raw flex, stage maximum_position | None | Device: convertToDegrees; saveCalibration | telemetry.calibrations |
| **8. Range Gained** | Patient views Completion screen | — | getAllMaximumCalibrationsForPatient (Supabase) | Device: compute difference | rehab.session_metrics or derived; Device cache |

---

### Realtime Feedback (During Lesson) – Not Persisted

| Scenario | Tolerance | Message |
|----------|-----------|---------|
| On pace | Within 25° of animation | Green |
| Too fast | >25° ahead + rate >1.5× expected | Red: "Slow down your movement!" |
| Too slow | >25° behind + rate <0.5× expected | Red: "Speed up your Rep!" |
| Thigh drift | IMU outside ±7 | Red: "Keep your thigh centered" |
| Max not reached | Not within 10° of max when animation hits top | Red: "Extend your leg further!" |

PT sets rep speed via restSec per lesson node on the Journey Map.

---

## 3. Replication Instructions

To recreate these diagrams in your preferred tool (e.g., Figma, Lucidchart, draw.io):

1. **Render Mermaid**: Use [mermaid.live](https://mermaid.live), GitHub, or VS Code (Mermaid extension) to view the diagrams.
2. **Export**: From Mermaid Live Editor, export as PNG or SVG.
3. **Manual recreation**: Flow moves left to right. Within each step: Pull (if any) above the user action; Tx, Proc, Storage below. User actions in the center row. Order: Pull → App → Tx → Proc → Storage (top to bottom within each column).
4. **Color coding**: Consider using distinct colors for App (blue), Tx (yellow), Pull (orange), Proc (gray), and Storage (green) for clarity.
