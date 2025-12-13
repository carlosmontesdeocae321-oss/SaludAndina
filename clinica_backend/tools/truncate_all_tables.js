#!/usr/bin/env node
/**
 * Script seguro para truncar todas las tablas de la base de datos conectada.
 * Protecciones:
 *  - requiere pasar `--confirm` en la línea de comandos para ejecutar realmente
 *  - imprime la lista de tablas que truncará antes de pedir confirmación adicional
 * Uso:
 *   node tools/truncate_all_tables.js --confirm
 * Nota: ejecuta este script en el entorno que quieras (local o en el servidor).
 */

const pool = require('../config/db');

function hasFlag(name) {
  return process.argv.some(a => a === name || a === `--${name}`);
}

async function main() {
  const confirmed = hasFlag('confirm');
  console.log('TRUNCATE ALL TABLES script - WARNING: This will permanently delete data.');
  if (!confirmed) {
    console.log('To proceed, re-run with: node tools/truncate_all_tables.js --confirm');
    process.exit(1);
  }

  try {
    // Get current schema/table list
    const [rows] = await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type='BASE TABLE'");
    const tables = (rows || []).map(r => r.table_name).filter(Boolean);
    if (!tables.length) {
      console.log('No tables found in current database. Nothing to do.');
      process.exit(0);
    }

    console.log('Found tables:');
    tables.forEach(t => console.log('  -', t));

    // Final confirmation prompt via stdin
    process.stdout.write('\nType YES to confirm truncation of the above tables: ');
    process.stdin.setEncoding('utf8');
    const input = await new Promise(resolve => process.stdin.once('data', d => resolve(d.trim())));
    if (input !== 'YES') {
      console.log('Aborting. You did not type YES.');
      process.exit(1);
    }

    console.log('\nDisabling foreign key checks and truncating tables...');
    await pool.query('SET FOREIGN_KEY_CHECKS = 0');
    for (const t of tables) {
      try {
        console.log('Truncating', t);
        await pool.query(`TRUNCATE TABLE \`${t}\``);
      } catch (e) {
        console.warn('Failed to truncate', t, e.message || e);
      }
    }
    await pool.query('SET FOREIGN_KEY_CHECKS = 1');

    console.log('\nDone. All listed tables were processed.');
    process.exit(0);
  } catch (err) {
    console.error('Error while truncating tables:', err.message || err);
    process.exit(2);
  }
}

main();
