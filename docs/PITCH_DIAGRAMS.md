# RealRehab — Pitch Diagrams

Two one-slide diagrams for the final capstone presentation. Render via GitHub or [mermaid.live](https://mermaid.live).

---

## Diagram 1 — System Level Diagram

How RealRehab works end-to-end: users, data flows, and core system components.

```mermaid
flowchart TD
    %% ── Actors ──────────────────────────────────────────────
    Patient(["🧑 Patient"])
    PT(["👩‍⚕️ Physical Therapist"])

    %% ── Hardware ─────────────────────────────────────────────
    Brace["🦵 BLE Knee Brace\n(IMU Sensor)"]

    %% ── App ──────────────────────────────────────────────────
    PatientApp["📱 Patient iOS App\n• Guided exercise lessons\n• Rep counting & real-time feedback\n• Journey map & progress"]
    PTApp["📱 PT iOS App\n• Patient roster & rehab plans\n• Session analytics\n• Notifications"]

    %% ── Backend ──────────────────────────────────────────────
    Cloud["☁️ Supabase Backend\n• User profiles & auth\n• Rehab plans & lesson progress\n• Sensor insights & calibrations"]

    %% ── AI ───────────────────────────────────────────────────
    AI["🤖 AI Summary\n(GPT-4o-mini)\nGenerates post-session\nlesson recaps"]

    %% ── Flows ────────────────────────────────────────────────
    Patient -- "Wears & pairs device" --> Brace
    Brace -- "Streams angle & motion data\nover Bluetooth" --> PatientApp
    Patient -- "Views plan, does reps,\nsees live feedback" --> PatientApp
    PatientApp -- "Saves progress, insights,\ncalibration data" --> Cloud
    PT -- "Creates plan, reviews\nanalytics, sends feedback" --> PTApp
    PTApp -- "Reads patient data,\nwrites plan & notes" --> Cloud
    Cloud -- "Triggers lesson summary" --> AI
    AI -- "Returns plain-language recap" --> PatientApp

    %% ── Styling ──────────────────────────────────────────────
    classDef actor fill:#1E3A5F,stroke:#1E3A5F,color:#fff,rx:8
    classDef device fill:#4A90D9,stroke:#4A90D9,color:#fff
    classDef app fill:#2D6A4F,stroke:#2D6A4F,color:#fff
    classDef backend fill:#6B4C9A,stroke:#6B4C9A,color:#fff
    classDef ai fill:#C77D3B,stroke:#C77D3B,color:#fff

    class Patient,PT actor
    class Brace device
    class PatientApp,PTApp app
    class Cloud backend
    class AI ai
```

---

## Diagram 2 — Technical Architecture Flow

The specific technologies powering each layer of the system.

```mermaid
flowchart LR
    %% ── Hardware ─────────────────────────────────────────────
    subgraph HW ["⚙️  Hardware"]
        Sensor["BLE Knee Brace\nIMU (flex angle,\nacceleration)"]
    end

    %% ── Mobile ───────────────────────────────────────────────
    subgraph Mobile ["📱  iOS App  (Swift / SwiftUI)"]
        BLE["CoreBluetooth\nStreams sensor data\nin real time"]
        Engine["Lesson Engine\nRep-counting state machine\nAngle zones & speed checks"]
        Cache["Offline Layer\nMemory + disk cache\nOutbox write queue"]
    end

    %% ── Backend ──────────────────────────────────────────────
    subgraph Backend ["☁️  Supabase"]
        Auth["Auth\nEmail / password\nRole-based (patient / PT)"]
        DB["PostgreSQL\naccounts · rehab · telemetry\nschemas"]
        Edge["Edge Function\nDeno · get-lesson-summary\nOrchestrates AI call"]
    end

    %% ── AI ───────────────────────────────────────────────────
    subgraph AILayer ["🤖  AI  (OpenAI)"]
        GPT["GPT-4o-mini\nGenerates session recap\nCached per lesson"]
    end

    %% ── Flows ────────────────────────────────────────────────
    Sensor -- "BLE GATT\ncharacteristics" --> BLE
    BLE --> Engine
    Engine -- "Rep results &\nsensor insights" --> Cache
    Cache -- "Sync when online\n(RPC upsert)" --> DB
    DB --> Edge
    Edge --> GPT
    GPT -- "Plain-language summary" --> DB

    Auth --> DB

    %% ── Styling ──────────────────────────────────────────────
    classDef hw fill:#4A90D9,stroke:#357ABD,color:#fff
    classDef mobile fill:#2D6A4F,stroke:#1E4D38,color:#fff
    classDef back fill:#6B4C9A,stroke:#4E3672,color:#fff
    classDef ai fill:#C77D3B,stroke:#9E612C,color:#fff

    class Sensor hw
    class BLE,Engine,Cache mobile
    class Auth,DB,Edge back
    class GPT ai
```

---

### Reading Guide

| Color | Layer |
|---|---|
| 🔵 Blue | Hardware (BLE knee brace) |
| 🟢 Green | iOS app (Swift / SwiftUI) |
| 🟣 Purple | Backend (Supabase — auth, database, edge functions) |
| 🟠 Orange | AI (OpenAI GPT-4o-mini) |
