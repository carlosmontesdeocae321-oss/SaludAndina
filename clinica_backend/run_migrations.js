const fs = require('fs');
const path = require('path');
const pool = require('./config/db');

async function runMigrations() {
  const migrationsDir = path.join(__dirname, 'migrations');
  if (!fs.existsSync(migrationsDir)) {
    console.error('No se encontró la carpeta migrations/');
    process.exit(1);
  }

  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    console.log('No hay archivos .sql en migrations/');
    process.exit(0);
  }

  for (const file of files) {
    const fullPath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(fullPath, 'utf8').trim();
    if (!sql) {
      console.log(`${file} está vacío, saltando`);
      continue;
    }

    console.log(`Ejecutando migración: ${file}`);

    const statements = sql
      .split(/;\s*(?:\r?\n|$)/)
      .map(stmt => stmt.trim())
      .filter(Boolean);

    try {
      for (const stmt of statements) {
        const alterTableMatch = stmt.match(/^\s*ALTER\s+TABLE\s+`?([a-zA-Z0-9_]+)`?/i);
        const addColumnMatch = stmt.match(/ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([a-zA-Z0-9_]+)`?/i);
        if (alterTableMatch && addColumnMatch) {
          const tableName = alterTableMatch[1];
          const columnName = addColumnMatch[1];
          const [existRows] = await pool.query(
            'SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
            [tableName, columnName]
          );
          const exists = existRows[0].c > 0;
          if (exists) {
            console.log(`  - Saltando columna ya existente '${columnName}' en '${tableName}'.`);
            continue;
          }
        }

        if (!stmt) continue;

        try {
          await pool.query(stmt);
        } catch (err) {
          const msg = err && (err.message || err.toString());
          if (msg && (/Duplicate column name/i.test(msg) || /Duplicate key name/i.test(msg))) {
            console.warn(`  - Aviso: ${msg}. Saltando statement.`);
            continue;
          }
          throw err;
        }
      }
      console.log(`OK: ${file}`);
    } catch (err) {
      const msg = err && (err.message || err.toString());
      console.error(`Error ejecutando ${file}:`, msg);
      console.error('Deteniendo migraciones. Revisa el error y corrige el SQL antes de reintentar.');
      await pool.end();
      process.exit(1);
    }
  }

  console.log('Todas las migraciones aplicadas.');
  await pool.end();
  process.exit(0);
}

runMigrations();
