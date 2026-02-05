# RealRehab Data Story - Professor Presentation

**RealRehab**: Connecting patients and physical therapists through sensor-guided rehabilitation.

---

## Part A: Project to Date

### Slide 1: The 3 Most Important Modules (In Order)

**1. Identity** → **2. Rehab Plan** → **3. Lesson Engine**

| Order | Module | What it does |
|-------|--------|--------------|
| 1 | Identity | Sign up, login, link patient to PT |
| 2 | Rehab Plan | PT creates lesson plan; patient progress saved |
| 3 | Lesson Engine | During lesson: green/red feedback from sensors |

---

### Slide 2: Module 1 – Identity (Data Flow)

```mermaid
flowchart LR
    A[User signs up or links to PT] --> B[App writes to cloud database]
    B --> C[(Cloud - permanent)]
    B -.-> D[Cache on device for offline launch]
```

**What happens**: Sign up, login, patient links to PT via code.  
**Data**: Login, name, DOB, surgery date, practice info.  
**Stored**: Cloud database (permanent). Device cache (temporary, for offline).

---

### Slide 3: Module 2 – Rehab Plan (Data Flow)

```mermaid
flowchart LR
    A[PT saves plan] --> B[(Cloud - permanent)]
    A2[Patient does lesson] --> C[Device file]
    C --> D[Upload queue]
    D -->|when online| B
```

**What happens**: PT creates plan → cloud. Patient does lesson → device file → upload queue → cloud when online.  
**Data**: Lesson list, reps done, time spent.  
**Stored**: Cloud (plans). Device file + queue (progress) → Cloud (when online).

---

### Slide 4: Module 3 – Lesson Engine (Data Flow)

```mermaid
flowchart LR
    A[Patient moves leg] --> B[Sensors check every 100ms]
    B --> C[Display green or red on screen]
    C --> D[Not stored anywhere]
```

**What happens**: Flex + IMU check every 100ms. Green = on pace; red = too fast, too slow, leg drift, or max not reached.  
**Data**: Sensor values (flex, IMU).  
**Stored**: Screen only. Nothing persisted today.

---

### Slide 5: Full Order of All Modules

```mermaid
flowchart LR
    M1[1. Registration] --> M2[2. PT-Patient Link]
    M2 --> M3[3. Prescription]
    M3 --> M4[4. Device Pairing]
    M4 --> M5[5. Calibration]
    M5 --> M6[6. Schedule]
    M6 --> M7[7. Training]
    M7 --> M8[8. Progress]
```

---

## Part B: Next Three Future Modules

### Slide 6: Future 1 – Schedule (Done)

```mermaid
flowchart LR
    A[Patient picks days and times] --> B[Writes to cloud database]
    B --> C[(Cloud - permanent)]
    B --> D[Schedules notifications on device]
```

**What happens**: Patient selects days and 30‑min slots; toggles reminders.  
**Data**: Days, times, reminders on/off.  
**Stored**: Cloud database (permanent). Device notifications (local).

---

### Slide 7: Future 2 – Sensor Insights (Bucket G)

```mermaid
flowchart LR
    A[Lesson turns red or green] --> B[Count each error type]
    B --> C[Write to device file]
    C --> D[Add to upload queue]
    D -->|when online| E[(Cloud - PT dashboard)]
```

**What happens**: Count errors (too fast, too slow, leg drift, max not reached, shake, knee over toe). Write to device file; add to queue; sync to cloud when online.  
**Data**: Error counts per lesson.  
**Stored**: Device file → Upload queue → Cloud (when online).

---

### Slide 8: Future 3 – Data Analysis

```mermaid
flowchart LR
    A[(Cloud - existing data)] --> B[PT queries by patient and date]
    B --> C[Display trends and recovery charts]
```

**What happens**: PT views trends, recovery charts, “patient improved on X this week.”  
**Data**: Quality, stability, biomechanics across lessons.  
**Stored**: Reads from cloud. No new writes.

---

## Slide Conversion Notes

- Slides 1–8. One module per slide.
- Mermaid: [mermaid.live](https://mermaid.live) → export PNG/SVG for slides.
