-- Add client_local_id column to pacientes to support client-server matching
-- This migration is idempotent when run via run_migrations.js
ALTER TABLE `pacientes`
  ADD COLUMN `client_local_id` VARCHAR(255) NULL;

-- Add index to speed up lookups by client_local_id
CREATE INDEX IF NOT EXISTS `idx_pacientes_client_local_id` ON `pacientes` (`client_local_id`);
