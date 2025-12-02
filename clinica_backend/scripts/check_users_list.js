const pool = require('../config/db');
(async () => {
  try {
    const [rows] = await pool.query("SELECT id, usuario, rol, clinica_id, dueno, creado_en FROM usuarios WHERE usuario IN ('keo','keo_test') ORDER BY usuario");
    console.log('Users found:', rows);
    process.exit(0);
  } catch (e) {
    console.error('Error querying users:', e);
    process.exit(1);
  }
})();
