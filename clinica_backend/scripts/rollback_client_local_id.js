const mysql = require('mysql2/promise');
const fs = require('fs');
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

async function tableHasIndex(connection, table, index) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?`,
    [table, index]
  );
  return rows[0].cnt > 0;
}

async function columnExists(connection, table, column) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) as cnt FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column]
  );
  return rows[0].cnt > 0;
}

async function run() {
  const cfg = {
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT) : 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || undefined,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  };

  console.log('Connecting to DB', cfg.host + ':' + cfg.port, 'db=', cfg.database);
  const conn = await mysql.createConnection(cfg);
  try {
    // historial
    const idxHist = 'idx_historial_client_local_id';
    const hasIdxHist = await tableHasIndex(conn, 'historial', idxHist).catch(() => false);
    if (hasIdxHist) {
      console.log('Dropping index', idxHist, 'from historial');
      await conn.execute(`ALTER TABLE historial DROP INDEX ${idxHist}`);
    } else {
      console.log('Index', idxHist, 'not present on historial');
    }
    const colHist = 'client_local_id';
    const hasColHist = await columnExists(conn, 'historial', colHist).catch(() => false);
    if (hasColHist) {
      console.log('Dropping column', colHist, 'from historial');
      await conn.execute(`ALTER TABLE historial DROP COLUMN ${colHist}`);
    } else {
      console.log('Column', colHist, 'not present on historial');
    }

    // pacientes
    const idxPac = 'idx_pacientes_client_local_id';
    const hasIdxPac = await tableHasIndex(conn, 'pacientes', idxPac).catch(() => false);
    if (hasIdxPac) {
      console.log('Dropping index', idxPac, 'from pacientes');
      await conn.execute(`ALTER TABLE pacientes DROP INDEX ${idxPac}`);
    } else {
      console.log('Index', idxPac, 'not present on pacientes');
    }
    const colPac = 'client_local_id';
    const hasColPac = await columnExists(conn, 'pacientes', colPac).catch(() => false);
    if (hasColPac) {
      console.log('Dropping column', colPac, 'from pacientes');
      await conn.execute(`ALTER TABLE pacientes DROP COLUMN ${colPac}`);
    } else {
      console.log('Column', colPac, 'not present on pacientes');
    }

    console.log('Rollback complete');
  } catch (e) {
    console.error('Error running rollback:', e && e.message ? e.message : e);
    process.exitCode = 2;
  } finally {
    await conn.end();
  }
}

run();
