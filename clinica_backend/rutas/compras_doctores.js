const express = require('express');
const router = express.Router();
const comprasDoctoresModelo = require('../modelos/comprasDoctoresModelo');
const { auth } = require('../middlewares/auth');

// Comprar doctor extra
// Esta ruta requiere autenticación (dueño o admin)
router.post('/comprar', auth, async (req, res) => {
  try {
    const { validarLimiteDoctores } = require('../utils/validacionLimites');
    const { cambiarPlanAClinicaVIP } = require('../utils/cambioPlanVIP');
    const usuariosModelo = require('../modelos/usuariosModelo');
    const clinica_id = req.body.clinica_id;
    const validacion = await validarLimiteDoctores(clinica_id);
    if (!validacion.permitido) {
      const planBaseLimite = (validacion.plan?.doctores_max || 0);
      if (validacion.totalDoctores >= planBaseLimite) {
        await cambiarPlanAClinicaVIP(clinica_id);
        const nuevaValidacion = await validarLimiteDoctores(clinica_id);
        if (!nuevaValidacion.permitido) {
          return res.status(403).json({ error: 'Límite de doctores alcanzado incluso en VIP. Contacte soporte.' });
        }
      } else {
        return res.status(403).json({ error: 'Límite de doctores alcanzado para su plan. Compre más extras o cambie de plan.' });
      }
    }
    // Registrar la compra: usar usuario autenticado como comprador si existe
    const compradorId = (req.user && req.user.id) ? req.user.id : req.body.usuario_id;
    const compraPayload = {
      clinica_id: clinica_id,
      usuario_id: compradorId,
      fecha_compra: new Date(),
      monto: req.body.monto || 5.0,
    };
    const id = await comprasDoctoresModelo.comprarDoctorExtra(compraPayload);
    // Crear usuario doctor automáticamente
    const { usuario, clave } = req.body; // Deben venir en el body
    if (!usuario || !clave) {
      return res.status(400).json({ error: 'Debe proporcionar usuario y clave para el nuevo doctor.' });
    }
    const nuevoDoctorId = await usuariosModelo.crearUsuario({ usuario, clave, rol: 'doctor', clinica_id });
    res.status(201).json({ compraId: id, doctorUsuarioId: nuevoDoctorId });
  } catch (err) {
    res.status(500).json({ error: 'Error al comprar doctor extra o crear usuario.' });
  }
});

// Validar si se puede agregar un doctor a la clínica (sin ejecutar la compra)
router.get('/validar/:clinica_id', auth, async (req, res) => {
  try {
    const clinica_id = req.params.clinica_id;
    const { validarLimiteDoctores } = require('../utils/validacionLimites');
    const validacion = await validarLimiteDoctores(clinica_id);
    return res.json({
      permitido: validacion.permitido,
      totalDoctores: validacion.totalDoctores,
      plan: validacion.plan,
      precioDoctorSlot: validacion.precioDoctorSlot || 5.0
    });
  } catch (err) {
    console.error('Error validando limite doctores:', err);
    return res.status(500).json({ error: 'Error interno al validar límite de doctores' });
  }
});

// Obtener total de doctores comprados
router.get('/:clinica_id', async (req, res) => {
  try {
    const total = await comprasDoctoresModelo.obtenerDoctoresComprados(req.params.clinica_id);
    res.json({ total });
  } catch (err) {
    res.status(500).json({ error: 'Error al consultar doctores comprados' });
  }
});

// Obtener lista de usuarios comprados para una clínica (usuario_id[])
router.get('/usuarios/:clinica_id', async (req, res) => {
  try {
    const lista = await comprasDoctoresModelo.obtenerUsuariosCompradosPorClinica(req.params.clinica_id);
    res.json({ usuarios: lista });
  } catch (err) {
    console.error('Error al obtener usuarios comprados por clínica:', err);
    res.status(500).json({ error: 'Error al consultar usuarios comprados' });
  }
});

// Comprar un slot de doctor (registro de compra sin crear usuario)
router.post('/comprar-slot', auth, async (req, res) => {
  try {
    const clinica_id = req.body.clinica_id || req.body.clinicaId;
    const monto = req.body.monto || 5.0;
    if (!clinica_id) return res.status(400).json({ error: 'clinica_id es requerido' });
    const compradorId = (req.user && req.user.id) ? req.user.id : null;
    const compraPayload = { clinica_id, usuario_id: compradorId, fecha_compra: new Date(), monto };
    const id = await comprasDoctoresModelo.comprarDoctorExtra(compraPayload);
    return res.status(201).json({ compraId: id });
  } catch (err) {
    console.error('Error comprar-slot:', err);
    return res.status(500).json({ error: 'Error interno al registrar compra de slot' });
  }
});

module.exports = router;
