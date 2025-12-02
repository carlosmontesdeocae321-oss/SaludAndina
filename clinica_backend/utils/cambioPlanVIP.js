const pool = require('../config/db');
const planesModelo = require('../modelos/planesModelo');

async function obtenerPlanVIP() {
  // Busca el plan VIP por nombre (ajusta si el nombre es diferente)
  const planes = await planesModelo.obtenerPlanes();
  return planes.find(p => p.nombre.toLowerCase().includes('vip'));
}

async function cambiarPlanAClinicaVIP(clinica_id) {
  const planVIP = await obtenerPlanVIP();
  if (!planVIP) throw new Error('No existe el plan VIP en la base de datos');
  // Desactiva el plan actual
  await pool.query('UPDATE clinica_planes SET activo = false WHERE clinica_id = ? AND activo = true', [clinica_id]);
  // Asigna el plan VIP
  const fecha_inicio = new Date();
  await pool.query(
    'INSERT INTO clinica_planes (clinica_id, plan_id, fecha_inicio, activo) VALUES (?, ?, ?, ?)',
    [clinica_id, planVIP.id, fecha_inicio, true]
  );
  return planVIP;
}

module.exports = {
  obtenerPlanVIP,
  cambiarPlanAClinicaVIP
};
