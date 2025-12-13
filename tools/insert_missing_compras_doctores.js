require('dotenv').config({ path: __dirname + '/../clinica_backend/.env' });
const mysql = require('mysql2/promise');

(async () => {
  const DB_HOST = process.env.DB_HOST || 'localhost';
  const DB_PORT = process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 3306;
  const DB_USER = process.env.DB_USER || 'root';
  const DB_PASSWORD = process.env.DB_PASSWORD || '';
  const DB_NAME = process.env.DB_NAME || 'clinica_db';

  const usuarioId = process.env.TARGET_USUARIO_ID || process.argv[2] || 14; // default to 14
  const clinicaId = process.env.TARGET_CLINICA_ID || process.argv[3] || 4; // default to 4
  const compraId = process.env.TARGET_COMPRA_ID || process.argv[4] || 7; // default to 7

  const pool = mysql.createPool({ host: DB_HOST, port: DB_PORT, user: DB_USER, password: DB_PASSWORD, database: DB_NAME });
  try {
    console.log('Conectando a DB', DB_HOST + ':' + DB_PORT, 'db=', DB_NAME);
    const [existsRows] = await pool.query('SELECT COUNT(*) as cnt FROM compras_doctores WHERE usuario_id = ? AND clinica_id = ? AND compra_id = ?', [usuarioId, clinicaId, compraId]);
    const cnt = existsRows && existsRows[0] ? existsRows[0].cnt : 0;
    if (cnt > 0) {
      console.log('Ya existe una fila en compras_doctores para usuario_id=', usuarioId, 'clinica_id=', clinicaId, 'compra_id=', compraId);
      process.exit(0);
    }

    const [res] = await pool.query('INSERT INTO compras_doctores (usuario_id, clinica_id, compra_id, creado_en) VALUES (?, ?, ?, NOW())', [usuarioId, clinicaId, compraId]);
    console.log('Insertado en compras_doctores id=', res.insertId);

    // Confirmar lectura
    const [rows] = await pool.query('SELECT usuario_id, clinica_id, compra_id, creado_en FROM compras_doctores WHERE id = ?', [res.insertId]);
    console.log('Fila insertada:', rows[0]);

    // Optional: also insert into pagos or firestore not required
    process.exit(0);
  } catch (e) {
    console.error('Error ejecutando inserción segura:', e.message || e);
    process.exit(2);
  } finally {
    try { await pool.end(); } catch(e){}
  }
})();
