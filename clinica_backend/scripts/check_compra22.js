const pool = require('../config/db');
(async () => {
  try {
    const [rows] = await pool.query('SELECT id, usuario_id, status, clinica_id, extra_data FROM compras_promociones WHERE id = ? LIMIT 1', [22]);
    console.log('Compra 22:', rows && rows[0] ? rows[0] : null);
    process.exit(0);
  } catch (e) {
    console.error('Error querying compra22:', e);
    process.exit(1);
  }
})();
