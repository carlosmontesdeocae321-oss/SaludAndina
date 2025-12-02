const fs = require('fs');
const path = require('path');
const pool = require('../config/db');

async function run() {
  const dbName = process.env.DB_NAME || 'clinica_db';
  const outDir = path.join(__dirname, '..', 'backups');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const ts = new Date().toISOString().replace(/[:.]/g, '-');

  console.log('Conectando a la base:', dbName);
  try {
    const [tables] = await pool.query(
      `SELECT table_name FROM information_schema.tables WHERE table_schema = ? AND table_type='BASE TABLE'`,
      [dbName]
    );

    if (!tables || tables.length === 0) {
      console.log('No se encontraron tablas en la base', dbName);
      process.exit(0);
    }

    // Backup: exportar cada tabla como JSON
    for (const row of tables) {
      // Algunas versiones devuelven la columna como TABLE_NAME en mayúsculas.
      const table = row.table_name || row.TABLE_NAME || Object.values(row)[0];
      console.log(`Exportando tabla ${table} ...`);
      try {
        const [rows] = await pool.query(`SELECT * FROM \`${table}\``);
        const file = path.join(outDir, `${dbName}__${table}__${ts}.json`);
        fs.writeFileSync(file, JSON.stringify(rows, null, 2), 'utf8');
        console.log(`  -> guardado ${file} (${rows.length} filas)`);
      } catch (e) {
        console.error(`  ! error exportando ${table}:`, e.message || e);
      }
    }

    // Truncar tablas: desactivar FK, truncar, reactivar
    console.log('Desactivando FOREIGN_KEY_CHECKS');
    await pool.query('SET FOREIGN_KEY_CHECKS = 0');

    for (const row of tables) {
      const table = row.table_name || row.TABLE_NAME || Object.values(row)[0];
      try {
        console.log(`Truncando ${table} ...`);
        await pool.query(`TRUNCATE TABLE \`${table}\``);
        console.log(`  -> truncado`);
      } catch (e) {
        console.error(`  ! error truncando ${table}:`, e.message || e);
      }
    }

    console.log('Reactivando FOREIGN_KEY_CHECKS');
    await pool.query('SET FOREIGN_KEY_CHECKS = 1');

    // Mostrar conteos finales
    console.log('\nConteos finales por tabla (deben ser 0):');
    for (const row of tables) {
      const table = row.table_name || row.TABLE_NAME || Object.values(row)[0];
      try {
        const [r] = await pool.query(`SELECT COUNT(*) as c FROM \`${table}\``);
        console.log(`${table}: ${r[0].c}`);
      } catch (e) {
        console.error(`  ! error contando ${table}:`, e.message || e);
      }
    }

    console.log('\nOperación completada. Backups JSON guardados en', outDir);
    process.exit(0);
  } catch (err) {
    console.error('Error general:', err.message || err);
    process.exit(1);
  }
}

run();
