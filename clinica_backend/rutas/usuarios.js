const express = require('express');
const router = express.Router();
const db = require('../config/db');
const usuariosModelo = require('../modelos/usuariosModelo');
const usuariosControlador = require('../controladores/usuariosControlador');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');
const doctorProfilesControlador = require('../controladores/doctorProfilesControlador');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Storage para avatars local (compatibilidad con varios endpoints antiguos)
const storageAvatars = multer.diskStorage({
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
const uploadAvatar = multer({ storage: storageAvatars });

// ---------------------------------
// RUTAS PÚBLICAS
// ---------------------------------

// Ruta pública para crear doctor individual (sin auth)
router.post('/', async (req, res) => {
  const { usuario, clave, rol, clinica_id } = req.body;
  if (rol === 'doctor' && !clinica_id) {
    if (!usuario || !clave || !rol) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }
    try {
      const nuevoId = await usuariosModelo.crearUsuario({ usuario, clave, rol, dueno: req.body.dueno });
      return res.status(201).json({ id: nuevoId, usuario, rol });
    } catch (err) {
      if (err && err.code === 'ER_DUP_ENTRY') {
        return res.status(400).json({ error: 'El usuario ya existe' });
      }
      return res.status(500).json({ error: 'Error al crear doctor individual: ' + (err && err.message ? err.message : err) });
    }
  }
  return res.status(403).json({ error: 'Solo se permite registrar doctor individual sin clínica en esta ruta.' });
});

// Endpoint para verificar si un nombre de usuario ya existe
router.get('/check', async (req, res) => {
  const usuario = req.query.usuario;
  if (!usuario) return res.status(400).json({ error: 'Falta parámetro usuario' });
  try {
    const [rows] = await db.query('SELECT COUNT(*) as cnt FROM usuarios WHERE usuario = ?', [usuario]);
    const exists = rows[0] && rows[0].cnt && rows[0].cnt > 0;
    res.json({ exists });
  } catch (err) {
    res.status(500).json({ error: 'Error al verificar usuario' });
  }
});

// Ruta pública para login
router.post('/login', usuariosControlador.login);

// Solicitar recuperación de contraseña (public)
router.post('/reset-request', usuariosControlador.requestPasswordReset);
// Realizar reset con token
router.post('/reset', usuariosControlador.performPasswordReset);

// Endpoint público para vincular doctor como dueño (si aplica flujo público)
router.post('/vincular-dueno', usuariosControlador.vincularDoctorComoDueno);

// Ruta pública para listar doctores (cuentas individuales y vinculadas)
router.get('/public', async (req, res) => {
  try {
    // Select only existing columns to avoid SQL errors on different schemas
    const [rows] = await db.query("SELECT id, usuario, rol, clinica_id FROM usuarios WHERE rol LIKE '%doctor%' ORDER BY usuario");
    res.json(rows);
  } catch (err) {
    console.error('Error en /api/usuarios/public:', err);
    res.status(500).json({ error: 'Error al obtener doctores' });
  }
});

// Ruta pública para obtener perfil público de un doctor por id
router.get('/public/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const [rows] = await db.query(
      `SELECT
         u.id,
         u.usuario,
         u.rol,
         u.clinica_id,
         dp.nombre AS nombre,
         dp.apellido AS apellido,
         dp.direccion AS direccion,
         dp.telefono,
         dp.email,
         dp.bio,
         dp.avatar_url,
         dp.especialidad,
         c.nombre AS clinica_nombre,
         COALESCE(pdoc.total_pacientes, pclinica.total_pacientes) AS totalPacientes
       FROM usuarios u
       LEFT JOIN doctor_profiles dp ON dp.user_id = u.id
       LEFT JOIN clinicas c ON c.id = u.clinica_id
       LEFT JOIN (
         SELECT doctor_id, COUNT(*) AS total_pacientes
         FROM pacientes
         WHERE doctor_id IS NOT NULL
         GROUP BY doctor_id
       ) AS pdoc ON pdoc.doctor_id = u.id
       LEFT JOIN (
         SELECT clinica_id, COUNT(*) AS total_pacientes
         FROM pacientes
         WHERE clinica_id IS NOT NULL
         GROUP BY clinica_id
       ) AS pclinica ON pclinica.clinica_id = u.clinica_id
       WHERE u.id = ?
       LIMIT 1`,
      [id]
    );
    if (!rows || rows.length === 0) return res.status(404).json({ error: 'Doctor no encontrado' });
    res.json(rows[0]);
  } catch (err) {
    console.error('Error en /api/usuarios/public/:id', err);
    res.status(500).json({ error: 'Error al obtener perfil del doctor' });
  }
});

// Ruta pública para listar documentos asociados a un usuario (doctor)
router.get('/:id/documentos', async (req, res) => {
  try {
    const id = req.params.id;
    const doctorDocumentsModelo = require('../modelos/doctorDocumentsModelo');
    const docs = await doctorDocumentsModelo.listarDocumentosPorUsuario(id);
    res.json(docs);
  } catch (err) {
    console.error('Error en /api/usuarios/:id/documentos', err);
    res.status(500).json({ error: 'Error al obtener documentos del doctor' });
  }
});

// Alias en inglés
router.get('/:id/photos', async (req, res) => {
  try {
    const id = req.params.id;
    const doctorDocumentsModelo = require('../modelos/doctorDocumentsModelo');
    const docs = await doctorDocumentsModelo.listarDocumentosPorUsuario(id);
    res.json(docs);
  } catch (err) {
    console.error('Error en /api/usuarios/:id/photos', err);
    res.status(500).json({ error: 'Error al obtener photos del doctor' });
  }
});

// ---------------------------------
// MIDDLEWARE: proteger rutas siguientes
// ---------------------------------
router.use(auth);
router.use(filtroClinica);

// Helper: solo admin
function soloAdmin(req, res, next) {
  // Permitir al platform-admin (rol 'admin' y dueno != 1) o al dueño de la clínica (dueno === true)
  const isPlatformAdmin = req.user && req.user.rol === 'admin' && !req.user.dueno;
  const isOwner = req.user && req.user.dueno === true;
  if (!isPlatformAdmin && !isOwner) {
    return res.status(403).json({ message: 'Acceso restringido: solo administradores o dueños de la clínica' });
  }
  next();
}

// ---------------------------------
// RUTAS PROTEGIDAS
// ---------------------------------
router.get('/', usuariosControlador.listarUsuarios);
router.get('/clinica/:clinicaId', async (req, res) => {
  const clinicaId = req.params.clinicaId;
  try {
    const [rows] = await db.query('SELECT id, usuario, rol, creado_en FROM usuarios WHERE clinica_id = ?', [clinicaId]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener usuarios por clínica' });
  }
});
router.get('/:id', usuariosControlador.verUsuario);
router.post('/vincular-dueno', usuariosControlador.vincularDoctorComoDueno);
router.put('/:id', soloAdmin, usuariosControlador.actualizarUsuario);
router.delete('/:id', soloAdmin, usuariosControlador.eliminarUsuario);

// Compatibilidad: aceptar uploads de avatar/imagen en rutas antiguas bajo /api/usuarios/:id
// Estas rutas se delegan al controlador de doctor_profiles para evitar 404 desde clientes.
router.post('/:id/avatar', auth, uploadAvatar.single('avatar'), doctorProfilesControlador.subirAvatar);
router.post('/:id/imagen', auth, uploadAvatar.single('imagen'), doctorProfilesControlador.subirAvatar);
router.post('/:id/foto', auth, uploadAvatar.single('imagen'), doctorProfilesControlador.subirAvatar);
router.post('/:id/upload-avatar', auth, uploadAvatar.single('imagen'), doctorProfilesControlador.subirAvatar);

module.exports = router;
