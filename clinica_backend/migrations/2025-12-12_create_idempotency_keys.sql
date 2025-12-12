-- Migration: create idempotency keys table for safe idempotent operations
CREATE TABLE IF NOT EXISTS idempotency_keys (
  idempotency_key VARCHAR(255) NOT NULL PRIMARY KEY,
  resource_type VARCHAR(64) NOT NULL,
  resource_id BIGINT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Keep small TTL via app logic; index on created_at can be added manually if desired
