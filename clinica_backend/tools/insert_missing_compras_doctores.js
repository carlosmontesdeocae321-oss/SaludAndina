require('dotenv').config({ path: __dirname + '/../.env' });
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
    // Detectar columnas existentes en compras_doctores para no romper esquemas distintos
    const [cols] = await pool.query("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'compras_doctores'", [DB_NAME]);
    const columnSet = new Set((cols || []).map(c => c.COLUMN_NAME));
    const hasCompraId = columnSet.has('compra_id');

    let existsQuery, existsParams;
    if (hasCompraId) {
      existsQuery = 'SELECT COUNT(*) as cnt FROM compras_doctores WHERE usuario_id = ? AND clinica_id = ? AND compra_id = ?';
      existsParams = [usuarioId, clinicaId, compraId];
    } else {
      existsQuery = 'SELECT COUNT(*) as cnt FROM compras_doctores WHERE usuario_id = ? AND clinica_id = ?';
      existsParams = [usuarioId, clinicaId];
    }

    const [existsRows] = await pool.query(existsQuery, existsParams);
    const cnt = existsRows && existsRows[0] ? existsRows[0].cnt : 0;
    if (cnt > 0) {
      console.log('Ya existe una fila en compras_doctores para usuario_id=', usuarioId, 'clinica_id=', clinicaId, hasCompraId ? ('compra_id=' + compraId) : '');
      process.exit(0);
    }

    let insertSql, insertParams;
    if (hasCompraId) {
      insertSql = 'INSERT INTO compras_doctores (usuario_id, clinica_id, compra_id, creado_en) VALUES (?, ?, ?, NOW())';
      insertParams = [usuarioId, clinicaId, compraId];
    } else if (columnSet.has('fecha_compra') && columnSet.has('monto')) {
      // Older schema used by comprasDoctoresModelo: (clinica_id, usuario_id, fecha_compra, monto)
      // Provide monto = 0.0 to satisfy NOT NULL constraints
      insertSql = 'INSERT INTO compras_doctores (clinica_id, usuario_id, fecha_compra, monto) VALUES (?, ?, NOW(), ?)';
      insertParams = [clinicaId, usuarioId, 0.0];
    } else {
      // Fallback: try to insert minimal columns (usuario_id, clinica_id, creado_en) if supported
      insertSql = 'INSERT INTO compras_doctores (usuario_id, clinica_id, creado_en) VALUES (?, ?, NOW())';
      insertParams = [usuarioId, clinicaId];
    }

    const [res] = await pool.query(insertSql, insertParams);
    console.log('Insertado en compras_doctores id=', res.insertId);

    // Confirmar lectura
    const [rows] = await pool.query('SELECT usuario_id, clinica_id, compra_id, creado_en FROM compras_doctores WHERE id = ?', [res.insertId]);
    console.log('Fila insertada:', rows[0]);

    process.exit(0);
  } catch (e) {
    console.error('Error ejecutando inserción segura:', e.message || e);
    process.exit(2);
  } finally {
    try { await pool.end(); } catch(e){}
  }
})();
