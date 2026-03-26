-- Restructure ACL Phase 1 with progressive rep/set/timing scheme.
-- Adds "sets" and "setRestSec" fields to all Phase 1 lesson nodes.
-- Phase 2–4 nodes and all patient plans (accounts.rehab_plans) are untouched.
--
-- Structure:
--   Round 1 (4 lessons): 10 reps, 1 set                     ← before benchmark
--   Round 2 (4 lessons): 15 reps, 1 set                     ← before benchmark
--   Benchmark 1: Extension Control
--   Round 3 (4 lessons): 20 reps, 2 sets                    ← after benchmark
--   Round 4 (4 lessons): 20 reps, 2–3 sets (Quad Sets 2, others 3)
--   Benchmark 2: Straight Leg Raise Control (10 reps, 7 sec)
--
-- restSec for Quad Sets = isometric hold duration (not between-rep rest).
-- setRestSec = rest between sets (always 60 sec default).

DO $$
DECLARE
  v_new_phase1 jsonb := '[
    {"id":"ac110001-0000-4000-8000-000000000001","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5, "sets":1,"setRestSec":60},
    {"id":"ac110002-0000-4000-8000-000000000002","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":6, "sets":1,"setRestSec":60},
    {"id":"ac110003-0000-4000-8000-000000000003","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":6, "sets":1,"setRestSec":60},
    {"id":"ac110004-0000-4000-8000-000000000004","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":6, "sets":1,"setRestSec":60},
    {"id":"ac110006-0000-4000-8000-000000000006","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":7, "sets":1,"setRestSec":60},
    {"id":"ac110007-0000-4000-8000-000000000007","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":6, "sets":1,"setRestSec":60},
    {"id":"ac110008-0000-4000-8000-000000000008","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":6, "sets":1,"setRestSec":60},
    {"id":"ac110009-0000-4000-8000-000000000009","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":15,"restSec":6, "sets":1,"setRestSec":60},
    {"id":"ac110011-0000-4000-8000-000000000011","title":"Extension Control",  "icon":"video","isLocked":false,"nodeType":"benchmark", "phase":1,"reps":0, "restSec":0, "sets":1,"setRestSec":60},
    {"id":"ac110012-0000-4000-8000-000000000012","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":7, "sets":2,"setRestSec":60},
    {"id":"ac110013-0000-4000-8000-000000000013","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":2,"setRestSec":60},
    {"id":"ac110014-0000-4000-8000-000000000014","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":2,"setRestSec":60},
    {"id":"ac110015-0000-4000-8000-000000000015","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":2,"setRestSec":60},
    {"id":"ac110017-0000-4000-8000-000000000017","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":10,"sets":2,"setRestSec":60},
    {"id":"ac110018-0000-4000-8000-000000000018","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":3,"setRestSec":60},
    {"id":"ac110019-0000-4000-8000-000000000019","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":3,"setRestSec":60},
    {"id":"ac110020-0000-4000-8000-000000000020","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":6, "sets":3,"setRestSec":60},
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

  RAISE NOTICE 'ACL Phase 1 restructured: 18 nodes (2 rounds × 4 lessons pre-benchmark, 2 rounds × 4 lessons post-benchmark, 2 benchmarks). sets + setRestSec added. Phases 2–4 unchanged.';
END;
$$;
