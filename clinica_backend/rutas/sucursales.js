const express = require('express');
const router = express.Router();
const sucursalesModelo = require('../modelos/sucursalesModelo');

// Vincular sucursal (solo Combo VIP)
router.post('/vincular', async (req, res) => {
  try {
    const id = await sucursalesModelo.vincularSucursal(req.body);
    res.status(201).json({ id });
  } catch (err) {
    res.status(500).json({ error: 'Error al vincular sucursal' });
  }
});

// Obtener sucursales vinculadas
router.get('/:clinica_principal_id', async (req, res) => {
  try {
    const sucursales = await sucursalesModelo.obtenerSucursales(req.params.clinica_principal_id);
    res.json(sucursales);
  } catch (err) {
    res.status(500).json({ error: 'Error al consultar sucursales' });
  }
});

module.exports = router;
