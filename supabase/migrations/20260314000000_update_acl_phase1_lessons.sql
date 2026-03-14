-- Update ACL Phase 1 plan template to use the 7 new evidence-based exercises.
-- Only Phase 1 nodes are replaced; Phases 2–4 and all other plan templates are untouched.
-- Existing patient plans in accounts.rehab_plans are NOT modified.

-- Step 1: Fetch the plan template id for Knee / ACL (used in CTE below).
-- Step 2: Delete all existing Phase 1 nodes from that template.
-- Step 3: Insert 22 new nodes (20 lessons + mid-benchmark at index 10 + end-benchmark at index 21).

DO $$
DECLARE
  v_template_id UUID;
BEGIN
  SELECT id INTO v_template_id
  FROM content.plan_templates
  WHERE category = 'Knee' AND injury = 'ACL'
  LIMIT 1;

  IF v_template_id IS NULL THEN
    RAISE NOTICE 'No Knee/ACL plan template found — skipping migration.';
    RETURN;
  END IF;

  -- Remove existing Phase 1 nodes
  DELETE FROM content.plan_template_nodes
  WHERE template_id = v_template_id AND phase = 1;

  -- Insert 22 Phase 1 nodes
  -- Indices 0–9: lessons before mid-benchmark (10 lessons)
  -- Index 10: mid-benchmark
  -- Indices 11–20: lessons after mid-benchmark (10 lessons)
  -- Index 21: end-benchmark
  INSERT INTO content.plan_template_nodes
    (template_id, phase, sort_order, node_type, title, default_reps, default_rest_sec)
  VALUES
    -- Lessons 1–10 (sort_order 0–9)
    (v_template_id, 1,  0, 'lesson',    'Quad Sets',                         10, 5),
    (v_template_id, 1,  1, 'lesson',    'Quad Sets — Extended Holds',         10, 8),
    (v_template_id, 1,  2, 'lesson',    'Short Arc Quad',                     10, 3),
    (v_template_id, 1,  3, 'lesson',    'Short Arc Quad — Control Focus',     12, 5),
    (v_template_id, 1,  4, 'lesson',    'Heel Slides',                        10, 8),
    (v_template_id, 1,  5, 'lesson',    'Seated Knee Extensions',             10, 3),
    (v_template_id, 1,  6, 'lesson',    'Seated Knee Extensions — Strength',  12, 5),
    (v_template_id, 1,  7, 'lesson',    'Quad Sets',                         10, 5),
    (v_template_id, 1,  8, 'lesson',    'Quad Sets — Extended Holds',         10, 8),
    (v_template_id, 1,  9, 'lesson',    'Short Arc Quad',                     10, 3),
    -- Mid-benchmark (sort_order 10)
    (v_template_id, 1, 10, 'benchmark', 'Straight Leg Raise Control (no knee lag)', 0, 0),
    -- Lessons 11–20 (sort_order 11–20)
    (v_template_id, 1, 11, 'lesson',    'Short Arc Quad — Control Focus',     12, 5),
    (v_template_id, 1, 12, 'lesson',    'Heel Slides',                        10, 8),
    (v_template_id, 1, 13, 'lesson',    'Seated Knee Extensions',             10, 3),
    (v_template_id, 1, 14, 'lesson',    'Seated Knee Extensions — Strength',  12, 5),
    (v_template_id, 1, 15, 'lesson',    'Quad Sets',                         10, 5),
    (v_template_id, 1, 16, 'lesson',    'Quad Sets — Extended Holds',         10, 8),
    (v_template_id, 1, 17, 'lesson',    'Short Arc Quad',                     10, 3),
    (v_template_id, 1, 18, 'lesson',    'Heel Slides',                        10, 8),
    (v_template_id, 1, 19, 'lesson',    'Seated Knee Extensions',             10, 3),
    (v_template_id, 1, 20, 'lesson',    'Seated Knee Extensions — Strength',  12, 5),
    -- End-benchmark (sort_order 21)
    (v_template_id, 1, 21, 'benchmark', 'Full Extension (0° or matches other side)', 0, 0);

  RAISE NOTICE 'ACL Phase 1 plan template updated with 7 new exercises (22 nodes total).';
END;
$$;
