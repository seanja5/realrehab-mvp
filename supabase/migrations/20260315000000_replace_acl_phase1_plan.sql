-- Replace ACL Phase 1 plan template with the 5 distinct evidence-based exercises.
-- Replaces the previous 7-exercise variant structure with the clean canonical set:
--   Quad Sets, Short Arc Quad, Heel Slides, Straight Leg Raise, Ankle Pumps
-- 22 nodes total: 4 rounds × 5 lessons + mid-benchmark + end-benchmark.
-- Phases 2–4 nodes and all patient plans (accounts.rehab_plans) are untouched.
-- Supersedes 20260314000000_update_acl_phase1_lessons.sql (which referenced
-- a non-existent content.plan_template_nodes table).

DO $$
DECLARE
  v_new_phase1 jsonb := '[
    {"id":"ac110001-0000-4000-8000-000000000001","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110002-0000-4000-8000-000000000002","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110003-0000-4000-8000-000000000003","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110004-0000-4000-8000-000000000004","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110005-0000-4000-8000-000000000005","title":"Ankle Pumps",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":3},
    {"id":"ac110006-0000-4000-8000-000000000006","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110007-0000-4000-8000-000000000007","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110008-0000-4000-8000-000000000008","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110009-0000-4000-8000-000000000009","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110010-0000-4000-8000-000000000010","title":"Ankle Pumps",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":3},
    {"id":"ac110011-0000-4000-8000-000000000011","title":"Extension Control",  "icon":"video","isLocked":false,"nodeType":"benchmark", "phase":1,"reps":0, "restSec":0},
    {"id":"ac110012-0000-4000-8000-000000000012","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110013-0000-4000-8000-000000000013","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110014-0000-4000-8000-000000000014","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110015-0000-4000-8000-000000000015","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110016-0000-4000-8000-000000000016","title":"Ankle Pumps",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":3},
    {"id":"ac110017-0000-4000-8000-000000000017","title":"Quad Sets",          "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":5},
    {"id":"ac110018-0000-4000-8000-000000000018","title":"Short Arc Quad",     "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110019-0000-4000-8000-000000000019","title":"Heel Slides",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110020-0000-4000-8000-000000000020","title":"Straight Leg Raise", "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":10,"restSec":3},
    {"id":"ac110021-0000-4000-8000-000000000021","title":"Ankle Pumps",        "icon":"video","isLocked":false,"nodeType":"lesson",    "phase":1,"reps":20,"restSec":3},
    {"id":"ac110022-0000-4000-8000-000000000022","title":"Straight Leg Raise Control","icon":"video","isLocked":false,"nodeType":"benchmark","phase":1,"reps":0,"restSec":0}
  ]'::jsonb;

  v_phase2to4 jsonb;
BEGIN
  -- Extract existing Phase 2–4 nodes preserving original order
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

  RAISE NOTICE 'ACL Phase 1 replaced: 22 nodes (Quad Sets × 4, Short Arc Quad × 4, Heel Slides × 4, Straight Leg Raise × 4, Ankle Pumps × 4, Extension Control benchmark, Straight Leg Raise Control benchmark). Phases 2–4 unchanged.';
END;
$$;
