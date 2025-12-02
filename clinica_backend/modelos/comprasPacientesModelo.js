const pool = require('../config/db');

async function comprarPacienteExtra({ clinica_id, fecha_compra, monto }) {
  if (!fecha_compra) {
    const [result] = await pool.query(
      'INSERT INTO compras_pacientes (clinica_id, fecha_compra, monto) VALUES (?, NOW(), ?)',
      [clinica_id, monto]
    );
    try {
      const { saveDoc } = require('../servicios/firebaseService');
      await saveDoc('compras_pacientes', result.insertId, { clinica_id, fecha_compra: new Date().toISOString(), monto });
    } catch (e) {
      console.warn('Warning: failed to save compras_pacientes to Firestore', e.message || e);
    }
    return result.insertId;
  }
  const [result] = await pool.query(
    'INSERT INTO compras_pacientes (clinica_id, fecha_compra, monto) VALUES (?, ?, ?)',
    [clinica_id, fecha_compra, monto]
  );
  try {
    const { saveDoc } = require('../servicios/firebaseService');
    await saveDoc('compras_pacientes', result.insertId, { clinica_id, fecha_compra: fecha_compra ? new Date(fecha_compra).toISOString() : null, monto });
  } catch (e) {
    console.warn('Warning: failed to save compras_pacientes to Firestore', e.message || e);
  }
  return result.insertId;
}

async function obtenerPacientesComprados(clinica_id) {
  const [rows] = await pool.query(
    'SELECT COUNT(*) as total FROM compras_pacientes WHERE clinica_id = ?',
    [clinica_id]
  );
  return rows[0].total;
}

module.exports = {
  comprarPacienteExtra,
  obtenerPacientesComprados,
};
