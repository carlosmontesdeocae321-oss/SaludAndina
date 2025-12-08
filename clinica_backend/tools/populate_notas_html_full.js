// Script to populate notas_html_full from notas_html when empty
const mysql = require('mysql2/promise');
const cfg = require('../config/config');

async function run() {
  const pool = mysql.createPool(cfg.db);
  try {
    const [rows] = await pool.query("SELECT id, notas_html, notas_html_full FROM historial WHERE notas_html_full IS NULL OR notas_html_full = ''");
    console.log('Rows to update:', rows.length);
    for (const r of rows) {
      const id = r.id;
      const full = r.notas_html || '';
      await pool.query('UPDATE historial SET notas_html_full = ? WHERE id = ?', [full, id]);
      console.log('Updated', id);
    }
    console.log('Done');
  } catch (e) {
    console.error('Error', e);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

if (require.main === module) run();

module.exports = run;
