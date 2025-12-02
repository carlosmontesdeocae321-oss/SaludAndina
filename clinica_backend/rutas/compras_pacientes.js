const express = require('express');
const router = express.Router();
const comprasPacientesModelo = require('../modelos/comprasPacientesModelo');
const comprasPacientesIndividualModelo = require('../modelos/comprasPacientesIndividualModelo');
const { auth } = require('../middlewares/auth');

// Comprar paciente extra
router.post('/comprar', auth, async (req, res) => {
  try {
    const { validarLimitePacientes } = require('../utils/validacionLimites');
    const { cambiarPlanAClinicaVIP } = require('../utils/cambioPlanVIP');
    // Permitir que el body especifique clinica_id, pero si el usuario autenticado
    // es un doctor vinculado a una clínica, usar su `req.user.clinica_id` como fallback.
    let clinica_id = req.body.clinica_id;
    if (!clinica_id && req.user && req.user.clinica_id) {
      clinica_id = req.user.clinica_id;
    }

    // Soporte: compra para doctor individual. Si no viene doctor_id en body, y el usuario
    // autenticado es un doctor individual, usamos su id.
    let doctorId = req.body.doctor_id;
    if (!doctorId && req.user && req.user.rol === 'doctor' && !req.user.clinica_id) {
      doctorId = req.user.id;
    }
    if (doctorId) {
      // Registrar compra para doctor individual
      const id = await comprasPacientesIndividualModelo.comprarPacienteExtraIndividual({ doctor_id: doctorId, monto: req.body.monto || 1.0 });
      return res.status(201).json({ id });
    }

    if (!clinica_id) {
      return res.status(400).json({ error: 'Falta clinica_id en la solicitud y el usuario no está asociado a una clínica.' });
    }

    const validacion = await validarLimitePacientes(clinica_id);
    if (!validacion.permitido) {
      const planBaseLimite = (validacion.plan?.pacientes_max || 0);
      if (validacion.totalPacientes >= planBaseLimite) {
        await cambiarPlanAClinicaVIP(clinica_id);
        const nuevaValidacion = await validarLimitePacientes(clinica_id);
        if (!nuevaValidacion.permitido) {
          return res.status(403).json({ error: 'Límite de pacientes alcanzado incluso en VIP. Contacte soporte.' });
        }
      } else {
        return res.status(403).json({ error: 'Límite de pacientes alcanzado para su plan. Compre más extras o cambie de plan.' });
      }
    }
    const id = await comprasPacientesModelo.comprarPacienteExtra(req.body);
    res.status(201).json({ id });
  } catch (err) {
    res.status(500).json({ error: 'Error al comprar paciente extra' });
  }
});

// Obtener total de pacientes comprados
router.get('/:clinica_id', async (req, res) => {
  try {
    const total = await comprasPacientesModelo.obtenerPacientesComprados(req.params.clinica_id);
    res.json({ total });
  } catch (err) {
    res.status(500).json({ error: 'Error al consultar pacientes comprados' });
  }
});

// Validar si se puede agregar paciente a la clínica (sin ejecutar la compra)
router.get('/validar/:clinica_id', auth, async (req, res) => {
  try {
    const clinica_id = req.params.clinica_id;
    const { validarLimitePacientes } = require('../utils/validacionLimites');
    const validacion = await validarLimitePacientes(clinica_id);
    return res.json({ permitido: validacion.permitido, totalPacientes: validacion.totalPacientes, plan: validacion.plan, precioPacienteSlot: validacion.precioPacienteSlot || 1.0 });
  } catch (err) {
    console.error('Error validando limite pacientes:', err);
    return res.status(500).json({ error: 'Error interno al validar límite de pacientes' });
  }
});

module.exports = router;
