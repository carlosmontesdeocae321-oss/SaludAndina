const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'ivar',
    database: process.env.DB_NAME || 'clinica_db',
    waitForConnections: true,
    connectionLimit: process.env.DB_CONNECTION_LIMIT ? parseInt(process.env.DB_CONNECTION_LIMIT, 10) : 10,
    queueLimit: 0,
    // Optionally enable SSL if provider requires it (set DB_SSL=true)
    ...(process.env.DB_SSL === 'true' ? { ssl: { rejectUnauthorized: false } } : {})
});

module.exports = pool;
