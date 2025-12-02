const express = require('express');
const router = express.Router();
const clinicaPlanesModelo = require('../modelos/clinicaPlanesModelo');

// Asignar plan a clínica
router.post('/asignar', async (req, res) => {
  try {
    const id = await clinicaPlanesModelo.asignarPlanAClinica(req.body);
    res.status(201).json({ id });
  } catch (err) {
    res.status(500).json({ error: 'Error al asignar plan a clínica' });
  }
});

// Consultar plan activo de una clínica
router.get('/:clinica_id', async (req, res) => {
  try {
    const plan = await clinicaPlanesModelo.obtenerPlanDeClinica(req.params.clinica_id);
    res.json(plan);
  } catch (err) {
    res.status(500).json({ error: 'Error al consultar plan de clínica' });
  }
});

module.exports = router;
