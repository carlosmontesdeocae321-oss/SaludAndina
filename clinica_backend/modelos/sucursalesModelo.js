const pool = require('../config/db');

async function vincularSucursal({ clinica_principal_id, clinica_vinculada_id }) {
  const [result] = await pool.query(
    'INSERT INTO sucursales (clinica_principal_id, clinica_vinculada_id) VALUES (?, ?)',
    [clinica_principal_id, clinica_vinculada_id]
  );
  return result.insertId;
}

async function obtenerSucursales(clinica_principal_id) {
  const [rows] = await pool.query(
    'SELECT c.* FROM sucursales s JOIN clinicas c ON s.clinica_vinculada_id = c.id WHERE s.clinica_principal_id = ?',
    [clinica_principal_id]
  );
  return rows;
}

module.exports = {
  vincularSucursal,
  obtenerSucursales,
};
