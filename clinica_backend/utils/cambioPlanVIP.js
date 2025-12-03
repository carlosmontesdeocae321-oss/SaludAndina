const { getPlanSpecBySlug, assignPlanToClinic } = require('./planHelper');

async function cambiarPlanAClinicaVIP(clinica_id) {
  const planSpec = getPlanSpecBySlug('combo_vip');
  if (!planSpec) throw new Error('Configuración de plan VIP no encontrada');
  await assignPlanToClinic({ clinicaId: clinica_id, planSpec });
  return planSpec;
}

module.exports = {
  cambiarPlanAClinicaVIP
};
