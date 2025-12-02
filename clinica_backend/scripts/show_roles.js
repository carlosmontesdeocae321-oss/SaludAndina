const pool = require('../config/db');
(async () => {
  try {
    const [rows] = await pool.query('SELECT DISTINCT rol FROM usuarios');
    console.log('Distinct roles:', rows);
    const [col] = await pool.query("SHOW COLUMNS FROM usuarios LIKE 'rol'");
    console.log('rol column definition:', col && col[0] ? col[0].Type : col);
    process.exit(0);
  } catch (e) {
    console.error('Error querying roles:', e);
    process.exit(1);
  }
})();
