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

  const limite = (planEffective?.doctores_max || 0) + (extra || 0);
  // Precios por slot (valores por defecto: doctor $5, paciente $1)
  const precioDoctorSlot = 5.0;

  return {
    permitido: totalDoctores < limite,
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

  const limite = (planEffective?.pacientes_max || 0) + (extra || 0);
  // Precio por slot de paciente
  const precioPacienteSlot = 1.0;

  return {
    permitido: totalPacientes < limite,
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
