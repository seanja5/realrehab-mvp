-- Add flex angle samples and calibration columns to lesson_sensor_insights
-- flex_angle_samples: per-rep angular position data (recorded only during active movement phases)
-- calibration_min_deg / calibration_max_deg: captured at lesson start for per-lesson velocity zone calculation

ALTER TABLE rehab.lesson_sensor_insights
  ADD COLUMN IF NOT EXISTS flex_angle_samples  jsonb            NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS calibration_min_deg double precision          DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS calibration_max_deg double precision          DEFAULT NULL;
