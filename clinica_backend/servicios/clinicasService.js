const clinicasModelo = require('../modelos/clinicasModelo');

async function listarClinicas() {
  return clinicasModelo.listarClinicas();
}

async function obtenerClinica(id) {
  return clinicasModelo.obtenerClinicaPorId(id);
}

async function crearClinica(payload) {
  // payload: { nombre, direccion, telefono_contacto, imagen_url }
  const id = await clinicasModelo.crearClinica(payload);
  return id;
}

async function actualizarClinica(id, campos) {
  return clinicasModelo.actualizarClinica(id, campos);
}

async function eliminarClinica(id) {
  return clinicasModelo.eliminarClinica(id);
}

async function estadisticas(id) {
  return clinicasModelo.estadisticasBasicas(id);
}

module.exports = {
  listarClinicas,
  obtenerClinica,
  crearClinica,
  actualizarClinica,
  eliminarClinica,
  estadisticas,
};
