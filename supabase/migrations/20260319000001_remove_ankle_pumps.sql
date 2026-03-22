-- Remove "Ankle Pumps" nodes from the ACL plan template.
-- Each segment goes from 5 lessons to 4: Quad Sets, Short Arc Quad, Heel Slides, Straight Leg Raise.

UPDATE content.plan_templates
SET nodes = (
  SELECT jsonb_agg(node ORDER BY ordinality)
  FROM jsonb_array_elements(nodes) WITH ORDINALITY AS t(node, ordinality)
  WHERE lower(node->>'title') NOT LIKE '%ankle pump%'
)
WHERE category = 'Knee' AND injury = 'ACL';
