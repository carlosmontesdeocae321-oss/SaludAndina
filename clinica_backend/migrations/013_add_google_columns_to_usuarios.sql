SET @dbName := DATABASE();

SET @addFirebaseUid := (
    SELECT IF(
        EXISTS(
            SELECT 1 FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = @dbName
                AND TABLE_NAME = 'usuarios'
                AND COLUMN_NAME = 'firebase_uid'
        ),
        'SELECT 1',
        'ALTER TABLE usuarios ADD COLUMN firebase_uid VARCHAR(128)'
    )
);
PREPARE stmt1 FROM @addFirebaseUid;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

SET @addGoogleEmail := (
    SELECT IF(
        EXISTS(
            SELECT 1 FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = @dbName
                AND TABLE_NAME = 'usuarios'
                AND COLUMN_NAME = 'google_email'
        ),
        'SELECT 1',
        'ALTER TABLE usuarios ADD COLUMN google_email VARCHAR(255)'
    )
);
PREPARE stmt2 FROM @addGoogleEmail;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

SET @addUniqueFirebase := (
    SELECT IF(
        EXISTS(
            SELECT 1 FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = @dbName
                AND TABLE_NAME = 'usuarios'
                AND INDEX_NAME = 'uq_usuarios_firebase_uid'
        ),
        'SELECT 1',
        'CREATE UNIQUE INDEX uq_usuarios_firebase_uid ON usuarios (firebase_uid)'
    )
);
PREPARE stmt3 FROM @addUniqueFirebase;
EXECUTE stmt3;
DEALLOCATE PREPARE stmt3;

SET @addEmailIndex := (
    SELECT IF(
        EXISTS(
            SELECT 1 FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = @dbName
                AND TABLE_NAME = 'usuarios'
                AND INDEX_NAME = 'idx_usuarios_google_email'
        ),
        'SELECT 1',
        'CREATE INDEX idx_usuarios_google_email ON usuarios (google_email)'
    )
);
PREPARE stmt4 FROM @addEmailIndex;
EXECUTE stmt4;
DEALLOCATE PREPARE stmt4;
