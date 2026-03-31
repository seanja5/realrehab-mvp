-- Replace "Straight Leg Raise" with "Knee Extension" in ACL Phase 1 lessons.
-- New exercise order: Quad Sets → Short Arc Quad → Knee Extension → Heel Slides
-- Round 1 restSec updated to 5 for all exercises (was 6 for Short Arc Quad, Heel Slides, and SLR).
-- Quad Sets restSec already 5 in Round 1; Round 2–4 Quad Sets progression unchanged.
-- Rounds 2–4 node IDs preserved where exercise is unchanged (Quad Sets, Short Arc Quad, Heel Slides).
-- Knee Extension gets new node IDs (ac110023–ac110026).
-- Existing patient plans (accounts.rehab_plans) are left unchanged.
--
-- Phase 1 structure (18 nodes):
--   Round 1 (4 lessons, reps:10, no sets): QS/SAQ/KE/HS — restSec all 5
--   Round 2 (4 lessons, reps:15, sets:1):  QS/SAQ/KE/HS — restSec 7/6/6/6
--   Benchmark 1: Extension Control
--   Round 3 (4 lessons, reps:20, sets:2):  QS/SAQ/KE/HS — restSec 7/6/6/6
--   Round 4 (4 lessons, reps:20, sets:2-3): QS/SAQ/KE/HS — restSec 10/6/6/6, sets 2/3/3/3
--   Benchmark 2: Straight Leg Raise Control (reps:10, restSec:7)

DO $$
DECLARE
  v_new_phase1 jsonb := '[
    {"id":"ac110001-0000-4000-8000-000000000001","title":"Quad Sets",       "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110002-0000-4000-8000-000000000002","title":"Short Arc Quad",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110023-0000-4000-8000-000000000023","title":"Knee Extension",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110003-0000-4000-8000-000000000003","title":"Heel Slides",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110006-0000-4000-8000-000000000006","title":"Quad Sets",       "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":7,"sets":1,"setRestSec":60},
    {"id":"ac110007-0000-4000-8000-000000000007","title":"Short Arc Quad",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":6,"sets":1,"setRestSec":60},
    {"id":"ac110024-0000-4000-8000-000000000024","title":"Knee Extension",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":6,"sets":1,"setRestSec":60},
    {"id":"ac110008-0000-4000-8000-000000000008","title":"Heel Slides",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":6,"sets":1,"setRestSec":60},
    {"id":"ac110011-0000-4000-8000-000000000011","title":"Extension Control","icon":"video","isLocked":false,"nodeType":"benchmark","phase":1,"reps":0, "restSec":0, "sets":1,"setRestSec":60},
    {"id":"ac110012-0000-4000-8000-000000000012","title":"Quad Sets",       "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":7,"sets":2,"setRestSec":60},
    {"id":"ac110013-0000-4000-8000-000000000013","title":"Short Arc Quad",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6,"sets":2,"setRestSec":60},
    {"id":"ac110025-0000-4000-8000-000000000025","title":"Knee Extension",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6,"sets":2,"setRestSec":60},
    {"id":"ac110014-0000-4000-8000-000000000014","title":"Heel Slides",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6,"sets":2,"setRestSec":60},
    {"id":"ac110017-0000-4000-8000-000000000017","title":"Quad Sets",       "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":10,"sets":2,"setRestSec":60},
    {"id":"ac110018-0000-4000-8000-000000000018","title":"Short Arc Quad",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":3,"setRestSec":60},
    {"id":"ac110026-0000-4000-8000-000000000026","title":"Knee Extension",  "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":3,"setRestSec":60},
    {"id":"ac110019-0000-4000-8000-000000000019","title":"Heel Slides",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":3,"setRestSec":60},
    {"id":"ac110022-0000-4000-8000-000000000022","title":"Straight Leg Raise Control","icon":"video","isLocked":false,"nodeType":"benchmark","phase":1,"reps":10,"restSec":7,"sets":1,"setRestSec":60}
  ]'::jsonb;

  v_phase2to4 jsonb;
BEGIN
  SELECT jsonb_agg(node ORDER BY ordinality)
    INTO v_phase2to4
    FROM content.plan_templates,
         jsonb_array_elements(nodes) WITH ORDINALITY AS t(node, ordinality)
   WHERE category = 'Knee' AND injury = 'ACL'
     AND (node->>'phase')::int > 1;

  IF NOT FOUND OR v_phase2to4 IS NULL THEN
    RAISE NOTICE 'No Knee/ACL plan template found or no Phase 2–4 nodes — skipping.';
    RETURN;
  END IF;

  UPDATE content.plan_templates
     SET nodes      = v_new_phase1 || v_phase2to4,
         updated_at = now()
   WHERE category = 'Knee' AND injury = 'ACL';

  RAISE NOTICE 'ACL Phase 1 updated: Straight Leg Raise → Knee Extension (slot 3), Heel Slides moved to slot 4. Round 1 restSec set to 5 for all exercises. Phases 2–4 unchanged.';
END;
$$;
