const express = require('express');
const router = express.Router();
const doctorProfilesControlador = require('../controladores/doctorProfilesControlador');
const doctorProfilesModelo = require('../modelos/doctorProfilesModelo');
const { auth } = require('../middlewares/auth');
// Nota: no aplicamos `filtroClinica` aquí de forma global porque permitimos
// que doctores individuales (sin `clinica_id`) gestionen su perfil y suban
// avatars/documentos. Aplicar `filtroClinica` globalmente bloqueaba a dichos
// usuarios.
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Guardar avatars en uploads/avatars
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, '..', 'uploads', 'avatars');
    try { fs.mkdirSync(dir, { recursive: true }); } catch (e) { }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  }
});
const upload = multer({ storage });

// Storage para documentos (certificados, títulos)
const storageDocs = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, '..', 'uploads', 'documents');
    try { fs.mkdirSync(dir, { recursive: true }); } catch (e) { }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  }
});
const uploadDocs = multer({ storage: storageDocs });

// Ruta pública para leer información básica del perfil extendido
router.get('/:userId/public', async (req, res) => {
  try {
    // Intentar Firestore primero
    const { getDoc } = require('../servicios/firebaseService');
    try {
      const doc = await getDoc('doctor_profiles', req.params.userId);
      if (doc) return res.json(doc);
    } catch (e) {
      // ignore and fallback to DB
    }

    const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(req.params.userId);
    if (!perfil) return res.status(404).json({ error: 'Perfil no encontrado' });
    res.json(perfil);
  } catch (err) {
    console.error('Error en GET /api/doctor_profiles/:userId/public', err);
    res.status(500).json({ error: 'Error al obtener perfil público del doctor' });
  }
});

// Rutas protegidas sólo por auth. Para endpoints que requieran clínica,
// aplicar `filtroClinica` de forma explícita en esos routes.
router.use(auth);

router.get('/:userId', doctorProfilesControlador.verPerfil);
router.put('/:userId', doctorProfilesControlador.crearOActualizarPerfil);
router.post('/:userId/avatar', upload.single('avatar'), doctorProfilesControlador.subirAvatar);
// Subir múltiples documentos (protegido)
router.post('/:userId/documents', uploadDocs.array('files', 20), doctorProfilesControlador.subirDocumentos);
router.post('/:userId/photos', uploadDocs.array('files', 20), doctorProfilesControlador.subirDocumentos);

module.exports = router;
