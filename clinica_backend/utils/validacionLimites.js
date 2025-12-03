const clinicaPlanesModelo = require('../modelos/clinicaPlanesModelo');
const comprasDoctoresModelo = require('../modelos/comprasDoctoresModelo');
const comprasPacientesModelo = require('../modelos/comprasPacientesModelo');
const usuariosModelo = require('../modelos/usuariosModelo');
const pacientesModelo = require('../modelos/pacientesModelo');

async function validarLimiteDoctores(clinica_id) {
  const plan = await clinicaPlanesModelo.obtenerPlanDeClinica(clinica_id);
  const extra = await comprasDoctoresModelo.obtenerDoctoresComprados(clinica_id);
  const usuarios = await usuariosModelo.obtenerUsuariosPorClinica(clinica_id);
  const totalDoctores = usuarios.filter(u => u.rol === 'doctor').length;
  // Aplicar overrides por nombre de plan (por si la BD no refleja el contrato esperado)
  const planEffective = Object.assign({}, plan || {});
  const planName = (planEffective.nombre || '').toString().toLowerCase();
  if (planName.includes('clínica pequeña')) {
    planEffective.doctores_max = 2;
    // El límite de pacientes de la pequeña será gestionado en validarLimitePacientes
  }
  if (planName.includes('clínica grande') || planName.includes('combo vip') || planName.includes('vip')) {
    planEffective.doctores_max = null;
  }

  const baseDoctores = Number(planEffective?.doctores_max);
  const unlimitedDoctores = planEffective?.doctores_max == null || !Number.isFinite(baseDoctores) || baseDoctores <= 0;
  const limiteBase = unlimitedDoctores ? Number.POSITIVE_INFINITY : baseDoctores;
  const limite = limiteBase === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : limiteBase + (extra || 0);
  planEffective.doctores_max = limiteBase === Number.POSITIVE_INFINITY ? null : limiteBase;

  // Precios por slot (valores por defecto: doctor $5, paciente $1)
  const precioDoctorSlot = 5.0;

  return {
    permitido: limite === Number.POSITIVE_INFINITY ? true : totalDoctores < limite,
    totalDoctores,
    limite,
    plan: planEffective,
    extra,
    precioDoctorSlot
  };
}

async function validarLimitePacientes(clinica_id) {
  const plan = await clinicaPlanesModelo.obtenerPlanDeClinica(clinica_id);
  const extra = await comprasPacientesModelo.obtenerPacientesComprados(clinica_id);
  const pacientes = await pacientesModelo.obtenerPacientesPorClinica(clinica_id);
  const totalPacientes = pacientes.length;
  // Aplicar overrides por nombre de plan
  const planEffective = Object.assign({}, plan || {});
  const planName = (planEffective.nombre || '').toString().toLowerCase();
  if (planName.includes('clínica pequeña')) {
    // Según requerimiento: tope de pacientes para "Clínica Pequeña"
    // Valor base forzado a 165
    planEffective.pacientes_max = 165;
  }
  if (planName.includes('clínica grande') || planName.includes('combo vip') || planName.includes('vip')) {
    planEffective.pacientes_max = null;
  }

  const basePacientes = Number(planEffective?.pacientes_max);
  const unlimitedPacientes = planEffective?.pacientes_max == null || !Number.isFinite(basePacientes) || basePacientes <= 0;
  const limiteBase = unlimitedPacientes ? Number.POSITIVE_INFINITY : basePacientes;
  const limite = limiteBase === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : limiteBase + (extra || 0);
  planEffective.pacientes_max = limiteBase === Number.POSITIVE_INFINITY ? null : limiteBase;

  // Precio por slot de paciente
  const precioPacienteSlot = 1.0;

  return {
    permitido: limite === Number.POSITIVE_INFINITY ? true : totalPacientes < limite,
    totalPacientes,
    limite,
    plan: planEffective,
    extra,
    precioPacienteSlot
  };
}

module.exports = {
  validarLimiteDoctores,
  validarLimitePacientes
};
