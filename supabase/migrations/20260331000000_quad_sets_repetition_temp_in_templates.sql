-- Quad Sets lesson nodes use two fields (camelCase JSON keys):
--   restSec               = repetition tempo — total seconds for lift + lower (default 6 → 3s up, 3s down in app)
--   timeHoldingPosition   = isometric hold at contraction (seconds); already used for Quad Sets
--
-- Legacy template rows often stored only restSec (meaning hold). This migration:
--   • Sets timeHoldingPosition to COALESCE(existing timeHoldingPosition, restSec) so hold is always explicit
--   • Sets restSec to 6 (default repetition tempo) unless restSec already differs from timeHoldingPosition
--     (meaning the plan already has separate tempo vs hold — keep that restSec)

CREATE OR REPLACE FUNCTION _migrate_quad_sets_nodes(p_nodes jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    (
      SELECT jsonb_agg(
        CASE
          WHEN (elem->>'nodeType') = 'lesson'
            AND (elem->>'title') ILIKE 'Quad Sets%'
          THEN
            elem
              || jsonb_build_object(
                   'timeHoldingPosition',
                   COALESCE(
                     (elem->>'timeHoldingPosition')::int,
                     (elem->>'restSec')::int
                   ),
                   'restSec',
                   CASE
                     WHEN (elem ? 'timeHoldingPosition')
                       AND (elem->>'restSec')::int IS DISTINCT FROM (elem->>'timeHoldingPosition')::int
                     THEN (elem->>'restSec')::int
                     ELSE 6
                   END
                 )
          ELSE elem
        END
        ORDER BY ordinality
      )
      FROM jsonb_array_elements(p_nodes) WITH ORDINALITY AS t(elem, ordinality)
    ),
    '[]'::jsonb
  );
$$;

UPDATE content.plan_templates
SET
  nodes = _migrate_quad_sets_nodes(nodes),
  updated_at = now()
WHERE category = 'Knee'
  AND injury = 'ACL'
  AND nodes IS NOT NULL;

UPDATE accounts.rehab_plans
SET nodes = _migrate_quad_sets_nodes(nodes)
WHERE nodes IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(nodes) AS elem
    WHERE (elem->>'nodeType') = 'lesson'
      AND (elem->>'title') ILIKE 'Quad Sets%'
  );

DROP FUNCTION _migrate_quad_sets_nodes(jsonb);
