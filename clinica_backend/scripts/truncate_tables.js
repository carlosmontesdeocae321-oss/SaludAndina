const pool = require('../config/db');

(async () => {
  const conn = await pool.getConnection();
  try {
    await conn.query('SET FOREIGN_KEY_CHECKS=0');
    const [rows] = await conn.query('SHOW TABLES');
    if (!rows || rows.length === 0) {
      console.log('No hay tablas para truncar.');
      return;
    }
    const key = Object.keys(rows[0])[0];
    const skipTables = new Set(['migrations']);
    for (const row of rows) {
      const tableName = row[key];
      if (!tableName || skipTables.has(tableName)) {
        console.log(`Saltando tabla ${tableName || '(desconocida)'}`);
        continue;
      }
      await conn.query(`TRUNCATE TABLE \`${tableName}\``);
      console.log(`Tabla ${tableName} truncada.`);
    }
    await conn.query('SET FOREIGN_KEY_CHECKS=1');
    console.log('Todas las tablas truncadas correctamente.');
  } catch (err) {
    console.error('Error truncando tablas:', err.message || err);
    process.exitCode = 1;
  } finally {
    conn.release();
    await pool.end();
  }
})();
