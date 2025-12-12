const pool = require('../config/db');

async function getByKey(key) {
    if (!key) return null;
    const [rows] = await pool.query('SELECT * FROM idempotency_keys WHERE idempotency_key = ? LIMIT 1', [key]);
    return rows && rows.length > 0 ? rows[0] : null;
}

async function createKey(key, resourceType, resourceId) {
    if (!key) return null;
    await pool.query('INSERT INTO idempotency_keys (idempotency_key, resource_type, resource_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE resource_id = VALUES(resource_id)', [key, resourceType, resourceId]);
    return await getByKey(key);
}

module.exports = {
    getByKey,
    createKey
};
