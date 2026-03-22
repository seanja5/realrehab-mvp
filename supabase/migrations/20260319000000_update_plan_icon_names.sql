-- Update icon field in ACL plan template nodes to match asset catalog names.
-- Icons are now custom image assets (used in JourneyMapView/PTJourneyMapView)
-- rather than the legacy "video" placeholder.
-- Order of CASE branches matters: "straight leg raise control" must precede "straight leg raise".

UPDATE content.plan_templates
SET nodes = (
  SELECT jsonb_agg(
    CASE
      WHEN lower(node->>'title') LIKE '%quad set%'                    THEN jsonb_set(node, '{icon}', '"quadsets"')
      WHEN lower(node->>'title') LIKE '%short arc%'                   THEN jsonb_set(node, '{icon}', '"shortarcquad"')
      WHEN lower(node->>'title') LIKE '%heel slide%'                  THEN jsonb_set(node, '{icon}', '"heelslides"')
      WHEN lower(node->>'title') LIKE '%straight leg raise control%'  THEN jsonb_set(node, '{icon}', '"straightlegraisecontrol"')
      WHEN lower(node->>'title') LIKE '%straight leg raise%'          THEN jsonb_set(node, '{icon}', '"straightlegraise"')
      WHEN lower(node->>'title') LIKE '%ankle pump%'                  THEN jsonb_set(node, '{icon}', '"anklepumps"')
      WHEN lower(node->>'title') LIKE '%extension control%'           THEN jsonb_set(node, '{icon}', '"extensioncontrol"')
      ELSE node
    END
  )
  FROM jsonb_array_elements(nodes) AS node
)
WHERE category = 'Knee' AND injury = 'ACL';
