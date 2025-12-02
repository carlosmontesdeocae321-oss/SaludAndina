const express = require('express');
const router = express.Router();
const citasControlador = require('../controladores/citasControlador');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');

router.use(auth);
router.use(filtroClinica);

router.get('/', citasControlador.listarCitas);
router.get('/:id', citasControlador.verCita);
router.post('/', citasControlador.crearCita);
router.put('/:id', citasControlador.actualizarCita);
router.delete('/:id', citasControlador.eliminarCita);

module.exports = router;
