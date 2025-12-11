const express = require('express');
const router = express.Router();
const historialControlador = require('../controladores/historialControlador');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configuración de multer: guardar en uploads/historial

const storage = multer.diskStorage({
	destination: function (req, file, cb) {
		const dir = path.join(__dirname, '..', 'uploads', 'historial');
		try { fs.mkdirSync(dir, { recursive: true }); } catch (e) { }
		cb(null, dir);
	},
	filename: function (req, file, cb) {
		const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
		cb(null, unique + path.extname(file.originalname));
	}
});
const upload = multer({ storage });

router.use(auth);
router.use(filtroClinica);

router.get('/', historialControlador.listarHistorial);
router.get('/paciente/:id', historialControlador.listarHistorialPorPaciente);
router.get('/by_client_local_id/:id', historialControlador.buscarPorClientLocalId);
router.get('/:id', historialControlador.verHistorial);
// Aceptar múltiples imágenes en campo 'imagenes'
router.post('/', upload.array('imagenes', 20), historialControlador.crearHistorial);
router.put('/:id', upload.array('imagenes', 20), historialControlador.actualizarHistorial);
router.delete('/:id', historialControlador.eliminarHistorial);

module.exports = router;
