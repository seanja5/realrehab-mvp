-- Remove sets and setRestSec from Round 1 nodes (ac110001-ac110004)
-- These are the first 4 lessons before the first benchmark; they have no set progression.

DO $$
DECLARE
  v_template_id UUID;
  v_nodes JSONB;
  v_node JSONB;
  v_idx INT;
  v_round1_ids TEXT[] := ARRAY['ac110001-0000-0000-0000-000000000000',
                                'ac110002-0000-0000-0000-000000000000',
                                'ac110003-0000-0000-0000-000000000000',
                                'ac110004-0000-0000-0000-000000000000'];
BEGIN
  SELECT id INTO v_template_id
  FROM content.plan_templates
  WHERE category = 'acl' AND injury = 'ACL Tear'
  LIMIT 1;

  IF v_template_id IS NULL THEN
    RAISE NOTICE 'No ACL template found, skipping';
    RETURN;
  END IF;

  SELECT nodes INTO v_nodes FROM content.plan_templates WHERE id = v_template_id;

  FOR v_idx IN 0 .. jsonb_array_length(v_nodes) - 1 LOOP
    v_node := v_nodes -> v_idx;
    IF (v_node ->> 'id') = ANY(v_round1_ids) THEN
      v_node := v_node - 'sets' - 'setRestSec';
      v_nodes := jsonb_set(v_nodes, ARRAY[v_idx::TEXT], v_node);
    END IF;
  END LOOP;

  UPDATE content.plan_templates SET nodes = v_nodes WHERE id = v_template_id;
  RAISE NOTICE 'Removed sets/setRestSec from Round 1 nodes in template %', v_template_id;
END;
$$;

-- Also remove from any existing live rehab plans (accounts.rehab_plans)
DO $$
DECLARE
  r RECORD;
  v_nodes JSONB;
  v_node JSONB;
  v_idx INT;
  v_round1_ids TEXT[] := ARRAY['ac110001-0000-0000-0000-000000000000',
                                'ac110002-0000-0000-0000-000000000000',
                                'ac110003-0000-0000-0000-000000000000',
                                'ac110004-0000-0000-0000-000000000000'];
BEGIN
  FOR r IN SELECT id, nodes FROM accounts.rehab_plans WHERE nodes IS NOT NULL LOOP
    v_nodes := r.nodes;
    FOR v_idx IN 0 .. jsonb_array_length(v_nodes) - 1 LOOP
      v_node := v_nodes -> v_idx;
      IF (v_node ->> 'id') = ANY(v_round1_ids) THEN
        v_node := v_node - 'sets' - 'setRestSec';
        v_nodes := jsonb_set(v_nodes, ARRAY[v_idx::TEXT], v_node);
      END IF;
    END LOOP;
    IF v_nodes IS DISTINCT FROM r.nodes THEN
      UPDATE accounts.rehab_plans SET nodes = v_nodes WHERE id = r.id;
    END IF;
  END LOOP;
  RAISE NOTICE 'Removed sets/setRestSec from Round 1 nodes in live rehab plans';
END;
$$;
