const pool = require('../config/db');

async function comprarPacienteExtraIndividual({ doctor_id, monto }) {
  const [result] = await pool.query(
    'INSERT INTO compras_pacientes_individual (doctor_id, monto) VALUES (?, ?)',
    [doctor_id, monto || 0.0]
  );
  try {
    const { saveDoc } = require('../servicios/firebaseService');
    await saveDoc('compras_pacientes_individual', result.insertId, { doctor_id, monto: monto || 0.0, creado_en: new Date().toISOString() });
  } catch (e) {
    console.warn('Warning: failed to save compras_pacientes_individual to Firestore', e.message || e);
  }
  return result.insertId;
}

async function obtenerPacientesCompradosIndividual(doctor_id) {
  const [rows] = await pool.query(
    'SELECT COUNT(*) AS total FROM compras_pacientes_individual WHERE doctor_id = ?',
    [doctor_id]
  );
  return rows[0] ? rows[0].total : 0;
}

module.exports = {
  comprarPacienteExtraIndividual,
  obtenerPacientesCompradosIndividual,
};
