-- Rollback: remove client_local_id columns and their indices
-- WARNING: This will DROP columns and indices. Ensure you want to lose these columns.

-- Drop index and column from `historial` if present
ALTER TABLE `historial` DROP INDEX IF EXISTS `idx_historial_client_local_id`;
ALTER TABLE `historial` DROP COLUMN IF EXISTS `client_local_id`;

-- Drop index and column from `pacientes` if present
ALTER TABLE `pacientes` DROP INDEX IF EXISTS `idx_pacientes_client_local_id`;
ALTER TABLE `pacientes` DROP COLUMN IF EXISTS `client_local_id`;

-- Commit note: After running this migration the server will no longer
-- receive or echo `client_local_id` values. Ensure clients are rolled back
-- to the previous behavior before applying.
