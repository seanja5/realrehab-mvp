#!/usr/bin/env python3
"""Generate plan_templates migration with embedded JSON seed."""
with open("supabase/seed_plan_template_nodes.json") as f:
    j = f.read()

d = "$json$"
sql = f"""-- Plan templates: default rehab plan structure by category+injury
-- Read-only for app; seeded via migration. PT edits go to accounts.rehab_plans.

CREATE SCHEMA IF NOT EXISTS content;

CREATE TABLE IF NOT EXISTS content.plan_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  injury text NOT NULL,
  nodes jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category, injury)
);

CREATE INDEX IF NOT EXISTS idx_plan_templates_category_injury
  ON content.plan_templates (category, injury);

ALTER TABLE content.plan_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY plan_templates_select_authenticated
  ON content.plan_templates
  FOR SELECT
  TO authenticated
  USING (true);

INSERT INTO content.plan_templates (category, injury, nodes)
VALUES ('Knee', 'ACL', {d}{j}{d}::jsonb)
ON CONFLICT (category, injury) DO NOTHING;
"""

with open("supabase/migrations/20260206000000_plan_templates.sql", "w") as out:
    out.write(sql)
print("Migration written.")
