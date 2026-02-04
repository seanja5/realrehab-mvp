-- ROLLBACK: Revert patient_lesson_progress migration
-- Drop policies, index, and table. No modifications to existing objects.

drop policy if exists patient_lesson_progress_select_own on accounts.patient_lesson_progress;
drop policy if exists patient_lesson_progress_insert_own on accounts.patient_lesson_progress;
drop policy if exists patient_lesson_progress_update_own on accounts.patient_lesson_progress;

drop index if exists accounts.idx_patient_lesson_progress_patient;

drop table if exists accounts.patient_lesson_progress;
