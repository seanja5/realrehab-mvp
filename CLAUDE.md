# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RealRehab is an iOS physical therapy app with a Supabase backend. It serves two user types:
- **Patients**: do guided knee-extension rehab exercises using a BLE-connected knee brace; view journey map and lesson progression; link to a PT via access code; set weekly schedule with optional reminders
- **Physical Therapists (PTs)**: manage patient list; assign and customize rehab plans; view patient progress and analytics; receive notifications when patients complete sessions

## Build & Run

This is an Xcode project — there are no `npm`, `make`, or `bun` commands.

```
open RealRehabPractice/RealRehabPractice.xcodeproj
```

- Run tests: `Cmd+U` in Xcode, or `xcodebuild test -scheme RealRehabPractice`
- Run a single test: click the diamond play button next to it in Xcode
- **XcodeBuildMCP** is available for build verification; preferred for build checks. Set `projectPath`, `scheme` (RealRehabPractice), `simulatorName` (e.g. iPhone 17)

For Supabase backend:
```bash
supabase db push
supabase functions deploy get-lesson-summary
```

## Adding New Swift Files (Critical)

When creating any new Swift file under `RealRehabPractice/` (excluding test bundles), **also update** `RealRehabPractice/RealRehabPractice.xcodeproj/project.pbxproj` in the same change. Xcode won't build files not listed there.

### Steps for each new file:
1. **Generate two unique 24-character hex IDs** — one for `PBXFileReference`, one for `PBXBuildFile`
2. Add a `PBXFileReference` entry (`lastKnownFileType = sourcecode.swift`)
3. Add a `PBXBuildFile` entry referencing the file ref
4. Add the file ref to the correct **PBXGroup** `children` array
5. Add the build file to `C89A84AD2EB138150074B855 /* Sources */` (main app target)

### PBXGroup IDs by folder:
| Folder | Group ID |
|--------|----------|
| `App/` | `C8D677BE2EB831BF00829144` |
| `Views/Onboarding/` | `C8D677C52EB8326500829144` |
| `Views/Home/` | `C8D677C62EB8327100829144` |
| `Views/Lessons/` | `C8D677C72EB8327900829144` |
| `Views/PTViews/` | `C8D677EF2EBA932000829144` |
| `Views/Settings/` | `C82D70362ED0AB17004D9347` |
| `Views/` | `C8D677C12EB831E500829144` |
| `Services/` | `C82D700D2EBE91D3004D9347` |
| `Services/BLE/` | `C8F4A6F02ED2C79A00BADF02` |
| `Services/Cache/` | `C82537722F2B12C300465343` |
| `ViewModels/` | `C82D70262EBEB10C004D9347` |
| `Models/` | `C8D677C22EB8321100829144` |
| `Components/` | `C8D677BF2EB831D600829144` |
| `Utilities/` | `C8D677C42EB8321E00829144` |
| `Resources/` | `C8D677C32EB8321800829144` |

## Architecture

### Dual-Role App
`SessionContext` (`@EnvironmentObject`) holds `profileId` and `ptProfileId`. On launch, `AuthService.resolveSessionForLaunch()` reads cached session from disk (works offline after restart) and sets role, then `Router.reset(to:)` navigates to the appropriate root:
- `role == "pt"` → `.patientList`
- `role == "patient"` → `.ptDetail`

### Navigation
`Router` is a `NavigationPath`-backed `ObservableObject` in `AppRouter.swift`. All navigation goes through `router.go(_:)`, `router.reset(to:)`, or `router.goWithoutAnimation(_:)` (for tab switching). All routes are in the `Route` enum. Tab bar routes: `ptDetail`, `journeyMap`, `patientSettings`, `ptSettings`, `patientList`.

### Service Layer
All Supabase access is in static `enum` services:
- **`AuthService`** — auth, profile, session bootstrap; `accounts.profiles`
- **`PatientService`** — patient profile CRUD, `myPatientProfileId`, `hasPT`, `getPTProfileId`, `linkPatientViaAccessCode`, `findPatientByAccessCode`, schedule reminders, `notifyPTSessionComplete` (RPC from CompletionView)
- **`PTService`** — PT profile, `listMyPatients`, `addPatient` (RPC `add_patient_with_mapping`), `updateNotificationPreferences`, `fetchRecentSessionCompleteEvents`; `pt_profiles.notify_session_complete` / `notify_missed_day`
- **`RehabService`** — rehab plans, lesson nodes, plan templates; `currentPlan`, `saveACLPlan`, `fetchPlan`, `updatePlanNotes`
- **`ScheduleService`** — `patient_schedule_slots`; 30-min blocks, 15-min granularity
- **`TelemetryService`** — BLE device assignment (RPC), calibrations; `getAllMaximumCalibrationsForPatient(before: Date?)` for per-lesson range gained
- **`MessagingService`** — PT↔patient messages
- **`NotificationManager`** — schedule reminders (T-15, T), PT session-complete notifications; categories `SCHEDULE_REMINDER`, `PT_SESSION_COMPLETE`
- **`LessonSummaryService`** — calls `get-lesson-summary` Edge Function
- **`LessonSensorInsightsService`** — fetches `rehab.lesson_sensor_insights`
- **`LessonSensorInsightsCollector`** — in-lesson event collection; draft persisted to disk; `pauseAndPersistDraft`, `resumeFromDraft`, `finishAndSaveDraft`; sync via `OutboxSyncManager`
- **`PTSessionCompleteNotifier`** — on PT app active, fetches new `pt_session_complete_events`, shows local notification; tap → patient detail

For Supabase writes that don't decode a body, use `.executeAsync()` (extension on `PostgrestBuilder` in `AuthService.swift`). Use `CacheKey` enum for all cache keys.

### Caching Strategy
`CacheService` (`@MainActor` singleton) provides memory-first + optional disk caching. Key TTLs:
- Resolved session: 7 days (disk) — enables offline app launch after restart
- Profile: 24h (disk)
- Rehab plan: 5 min; Patient list/detail: 5–10 min

When offline, `allowStaleWhenOffline: true` returns expired entries so UI can show last-known data. Call `invalidate`/`setCached` after writes to keep UI consistent.

### Offline-First Write Queue (Outbox)
`OutboxSyncManager` (`@MainActor` singleton) queues writes to `RealRehabOutbox/outbox.json`. Processes on app foreground and when network comes back online. Exponential backoff, max 5 retries then dropped.

### Lesson Flow
1. Journey Map "Go!" on a lesson → `calibrateDevice(reps, restSec, lessonId)` → `DirectionsView1` → `DirectionsView2` → `LessonView`
2. `LessonEngine` drives rep-counting state machine (idle → upstroke → downstroke → cooldown); `BluetoothManager` streams BLE sensor data
3. `LessonSensorInsightsCollector` counts real-time error events (drift, too fast/slow, shake)
4. On completion → `AssessmentView(lessonId)` → `CompletionView(lessonId)`
5. `CompletionView` calls `PatientService.notifyPTSessionComplete` (inserts into `pt_session_complete_events` if PT has `notify_session_complete = true`)
6. Lesson progress queued in `OutboxSyncManager`, synced via Supabase RPC `accounts.upsert_patient_lesson_progress`

**Calibration** happens before every lesson (not during initial pair). `PairDeviceView` dismisses after successful pair and returns to previous screen — no calibration in that flow. `CalibrateDeviceView(reps, restSec, lessonId, fromUnpause, onFinish)`: when `fromUnpause == true`, shows recalibration message and calls `onFinish?()` instead of navigating.

**Pause/resume**: On pause, `LessonSensorInsightsCollector.pauseAndPersistDraft` writes draft to disk. On resume, LessonView shows full-screen `CalibrateDeviceView` with `fromUnpause: true`; after recalibration, `resumeFromDraft(lessonId:)` restores state and sampling continues.

### CompletionView & Score
- **Score** (`PatientLessonScore.compute(insights)`): rep completion 40%, drift 25%, steadiness 20%, pace 15%. Range 0–100.
- **Circle animation**: `TimelineView(.animation(minimumInterval: 1/60))` driven. Score number shows immediately; circle fills over 1.2s with ease-out `1 - (1-t)²`. State: `animationStartTime`, `targetProgress`.
- **Loading**: `isScreenLoading = isLoadingInsights || isLoadingRange`. Full-screen skeleton for header and metric cards. Score circle shows empty with "—" while loading (no shimmer on the circle itself).
- **Range gained**: `TelemetryService.getAllMaximumCalibrationsForPatient(before: insights?.completed_at)` — per-lesson range (latest max minus previous max as of that lesson's `completed_at`).

### LessonAnalyticsView (PT)
Uses `AnalyticsSummaryBoxesView` with: full-width rep accuracy box (pie chart); session time + rest side by side. Graph titles: "Leg Drift", "Leg Shake / Tremor". `restSec` comes from `RehabService.currentPlan` for the lesson. Pie stroke uses `lineCap: .butt`.

### PT Notifications
- `pt_profiles.notify_session_complete` (default true), `notify_missed_day` (default false)
- `pt_session_complete_events` table: `pt_profile_id`, `patient_profile_id`, patient name, `lesson_id`, `lesson_title`, `created_at`
- When patient app reaches CompletionView with a `lessonId`, calls RPC `notify_pt_session_complete` — inserts event only if PT has `notify_session_complete = true`
- PT app on active: `PTSessionCompleteNotifier.checkAndNotify` fetches new events, shows local notification; notified IDs tracked in UserDefaults

### PT Patient Invite Flow
Invite button shown only when patient is not linked (`profile_id == nil`). `ShareSheetHelper.activityItems(for: code)` shares: a ShareImage, message text, and https URL. Button stays until patient actually links. Deep link `realrehab://link?code=<8-digit>` handled in `RealRehabPracticeApp.onOpenURL`; code stored in `PendingLinkStore` for pre-fill in CreateAccount/PatientSettings.

### Supabase Schemas
| Schema | Key Tables |
|--------|-----------|
| `accounts` | profiles, patient_profiles, pt_profiles, pt_patient_map, rehab_plans, patient_lesson_progress, patient_schedule_slots, pt_session_complete_events |
| `content` | plan_templates (default rehab plans per category/injury) |
| `rehab` | assignments, programs, lessons (legacy); lesson_ai_summaries (AI summary cache); lesson_sensor_insights |
| `telemetry` | devices, device_assignments, calibrations |

### Edge Functions
- **`get-lesson-summary`** (Deno/TypeScript): calls OpenAI `gpt-4o-mini`; caches results in `rehab.lesson_ai_summaries` (keyed by `lesson_id`, `patient_profile_id`, `audience`). Requires secrets `OPENAI_API_KEY` and `SERVICE_ROLE_KEY` in Supabase Dashboard > Edge Functions > Secrets.

### UI Conventions
- **Typography**: Use `Theme.*` or `Font.rr*` only (`.rrHeadline`, `.rrTitle`, `.rrBody`, `.rrCallout`, `.rrCaption`). No raw `.font(.system(...))`.
- **Colors**: `Color.brandDarkBlue`, `Color.brandLightBlue`; page background via `.rrPageBackground()`
- **Spacing**: `RRSpace.pageTop`, `RRSpace.section`, `RRSpace.stack`; horizontal padding 16–20pt
- **Navigation**: Inline title; `BackButton()` in toolbar (except WelcomeView). `PrimaryButton` / `SecondaryButton` for actions.
- **Layout**: `ScrollView` for long content; bottom buttons via `.safeAreaInset(edge: .bottom)`; sticky headers via `.safeAreaInset(edge: .top)`
- App forced to Light mode app-wide (`preferredColorScheme(.light)`)
- `SkeletonShimmer` for loading states

### Local File Storage Paths
| Path | Purpose |
|------|---------|
| `RealRehabCache/*.json` | API response cache |
| `RealRehabOutbox/outbox.json` | Pending sync queue |
| `RealRehabLessonProgress/{lessonId}.json` | Offline lesson draft (resume mid-session) |
| `RealRehabSensorInsights/{lessonId}.json` | Sensor event draft (synced via Outbox) |
| `SupabaseConfig.plist` | Supabase URL + anon key (not committed) |

## Adding a New Screen or Feature

1. Add route in `AppRouter.swift` and destination in `RealRehabPracticeApp.swift`
2. Use the service that owns the domain (patient profile → PatientService, PT/patients → PTService, plans → RehabService, schedule → ScheduleService, sensor/calibration → TelemetryService)
3. For new RPCs: add in Supabase, call from the appropriate service
4. Cache: use `CacheKey` enum; call `invalidate`/`setCached` after writes
5. Apply `Theme` + `.rrPageBackground()` + `BackButton()` where appropriate

## Key Files

| File | Purpose |
|------|---------|
| `App/AppRouter.swift` | `Route` enum + `Router` |
| `App/RealRehabPracticeApp.swift` | App entry, session bootstrap, deep link, notification handling |
| `App/NotificationDelegate.swift` | Notification tap → route (journeyMap, ptPatientDetail) |
| `Components/Theme.swift` | Typography, spacing, background helpers |
| `Components/Components.swift` | Shared UI components |
| `Components/AnalyticsSummaryBoxesView.swift` | Analytics boxes for lesson analytics |
| `Models/SessionContext.swift` | `profileId`, `ptProfileId` |
| `Models/SchedulingModels.swift` | Weekday, DayTime, ScheduleSlot |
| `Services/SupabaseService.swift` | Shared `SupabaseClient`, config from plist |
| `Utilities/PatientLessonScore.swift` | Score computation (40/25/20/15 weights) |
| `Views/Lessons/CompletionView.swift` | Post-lesson completion, score circle, range gained |
| `Views/Lessons/LessonView.swift` | Live lesson with BLE, rep counting, pause/resume |
| `Views/PTViews/LessonAnalyticsView.swift` | PT lesson analytics view |
| `RealRehabPractice.xcodeproj/project.pbxproj` | Must update when adding any new file |
