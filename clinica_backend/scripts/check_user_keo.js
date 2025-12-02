const pool = require('../config/db');
(async () => {
  try {
    const [rows] = await pool.query("SELECT id, usuario, rol, clinica_id, dueno, creado_en FROM usuarios WHERE usuario = ? LIMIT 10", ['keo']);
    console.log('Found users:', rows);
    process.exit(0);
  } catch (e) {
    console.error('Error querying DB:', e);
    process.exit(1);
  }
})();
