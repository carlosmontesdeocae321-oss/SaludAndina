const clinicasModelo = require('../modelos/clinicasModelo');
const usuariosModelo = require('../modelos/usuariosModelo');
(async () => {
  try {
    console.log('Creating test clinica...');
    const clinicaId = await clinicasModelo.crearClinica({ nombre: 'TestClinicaAuto', direccion: 'Nowhere' });
    console.log('Created clinicaId:', clinicaId);
    console.log('Creating user via crearUsuarioClinicaAdmin...');
    const userId = await usuariosModelo.crearUsuarioClinicaAdmin({ usuario: 'keo_test', clave: 'keo123', rol: 'clinica', clinica_id: clinicaId });
    console.log('Created userId:', userId);
    process.exit(0);
  } catch (e) {
    console.error('Error in test script:', e);
    process.exit(1);
  }
})();
