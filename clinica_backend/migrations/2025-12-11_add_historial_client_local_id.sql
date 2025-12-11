-- Add client_local_id to historial for deduplication
ALTER TABLE historial ADD COLUMN client_local_id VARCHAR(255) NULL;
CREATE INDEX idx_historial_client_local_id ON historial(client_local_id);
