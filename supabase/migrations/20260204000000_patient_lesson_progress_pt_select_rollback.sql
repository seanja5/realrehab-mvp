-- Rollback: remove PT select policy
drop policy if exists patient_lesson_progress_select_pt on accounts.patient_lesson_progress;
