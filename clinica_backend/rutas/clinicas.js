const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const db = require('../config/db');
const { uploadFile } = require('../servicios/cloudinaryService');
const { auth } = require('../middlewares/auth');
const clinicasService = require('../servicios/clinicasService');
const usuariosModelo = require('../modelos/usuariosModelo');

const uploadsDir = path.join(__dirname, '..', 'uploads', 'clinicas');

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    fs.mkdirSync(uploadsDir, { recursive: true });
    cb(null, uploadsDir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext && ext.length <= 5 ? ext : '';
    cb(null, `clinic_${Date.now()}${safeExt}`);
  },
});

const upload = multer({ storage });

// Obtener todas las clínicas
router.get('/', async (req, res) => {
  try {
    const rows = await clinicasService.listarClinicas();
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener clínicas' });
  }
});

// Obtener detalles de una clínica
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const row = await clinicasService.obtenerClinica(id);
    if (!row) return res.status(404).json({ error: 'Clínica no encontrada' });
    res.json(row);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener clínica' });
  }
});

// Crear una nueva clínica (protegido: admin o dueño)
router.post('/', auth, async (req, res) => {
  const { nombre, direccion, telefono_contacto } = req.body;
  if (!nombre) return res.status(400).json({ error: 'El nombre es obligatorio' });
  try {
    // Permitir solo admin o usuarios con rol 'admin' en el sistema
    const user = req.user || {};
    if (user.rol !== 'admin') return res.status(403).json({ error: 'No autorizado' });
    const newId = await clinicasService.crearClinica({ nombre, direccion, telefono_contacto });
    // Firestore sync
    try {
      const { saveDoc } = require('../servicios/firebaseService');
      await saveDoc('clinics', newId, { nombre: nombre || null, direccion: direccion || null });
    } catch (e) {
      console.warn('Warning: failed to save clinica to Firestore', e.message || e);
    }
    res.status(201).json({ id: newId, nombre, direccion });
  } catch (err) {
    console.error('Error crear clínica (route):', err);
    res.status(500).json({ error: 'Error al crear clínica' });
  }
});

// Eliminar clínica por id
router.delete('/:id', auth, async (req, res) => {
  const { id } = req.params;
  try {
    const user = req.user || {};
    // Only platform admin or clinic owner (dueno) or clinic-role account for this clinic can delete
    if (!(user.rol === 'admin' || (user.rol === 'clinica' && Number(user.clinica_id) === Number(id)) || (user.clinica_id && Number(user.clinica_id) === Number(id) && user.dueno))) {
      return res.status(403).json({ error: 'No autorizado' });
    }

    const [result] = await db.query('DELETE FROM clinicas WHERE id = ?', [id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Clínica no encontrada' });
    }
    try {
      const { deleteDoc } = require('../servicios/firebaseService');
      await deleteDoc('clinics', id);
    } catch (e) {
      console.warn('Warning: failed to delete clinica from Firestore', e.message || e);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al eliminar clínica' });
  }
});

// Actualizar datos públicos de la clínica (imagen, dirección, teléfono)
// Actualizar datos públicos de la clínica (imagen, dirección, teléfono)
router.put('/:id/perfil', auth, upload.single('imagen'), async (req, res) => {
  const { id } = req.params;
  const {
    direccion,
    telefono_contacto: telefonoContacto,
    imagen_url: imagenUrlField,
  } = req.body;

  const fields = [];
  const values = [];

  if (typeof direccion !== 'undefined') {
    fields.push('direccion = ?');
    values.push(direccion);
  }

  if (typeof telefonoContacto !== 'undefined') {
    fields.push('telefono_contacto = ?');
    values.push(telefonoContacto);
  }

  let finalImageUrl = null;
  if (req.file) {
    try {
      const r = await uploadFile(req.file.path, { folder: 'clinica/clinicas' });
      finalImageUrl = r.secure_url;
    } catch (e) {
      console.error('Error subiendo imagen a Cloudinary:', e);
      return res.status(500).json({ error: 'Error subiendo imagen' });
    }
  } else if (typeof imagenUrlField !== 'undefined') {
    const trimmed = (imagenUrlField || '').trim();
    if (trimmed.length) {
      finalImageUrl = trimmed;
    } else {
      fields.push('imagen_url = NULL');
    }
  }

  if (finalImageUrl) {
    fields.push('imagen_url = ?');
    values.push(finalImageUrl);
  }

  if (!fields.length) {
    return res
      .status(400)
      .json({ error: 'No se enviaron campos para actualizar la clínica' });
  }

  try {
    // Permisos: admin, clinic-role account for the same clinic, or dueño (owner)
    const user = req.user || {};
    if (!(user.rol === 'admin' || (user.rol === 'clinica' && Number(user.clinica_id) === Number(id)) || (user.clinica_id && Number(user.clinica_id) === Number(id) && user.dueno))) {
      return res.status(403).json({ error: 'No autorizado para actualizar esta clínica' });
    }

    const campos = {};
    if (typeof direccion !== 'undefined') campos.direccion = direccion;
    if (typeof telefonoContacto !== 'undefined') campos.telefono_contacto = telefonoContacto;
    if (finalImageUrl) campos.imagen_url = finalImageUrl;

    await clinicasService.actualizarClinica(id, campos);
    const updated = await clinicasService.obtenerClinica(id);
    // Actualizar Firestore
    try {
      const { saveDoc } = require('../servicios/firebaseService');
      await saveDoc('clinics', id, { nombre: updated.nombre || null, direccion: updated.direccion || null, imagen_url: updated.imagen_url || null, telefono_contacto: updated.telefono_contacto || null });
    } catch (e) {
      console.warn('Warning: failed to update clinica in Firestore', e.message || e);
    }
    res.json(updated);
  } catch (err) {
    console.error('Error actualizando clínica', err);
    res.status(500).json({ error: 'Error al actualizar la clínica' });
  }
});

// Rutas para gestionar usuarios de una clínica (owner o admin)
router.get('/:id/usuarios', auth, async (req, res) => {
  const { id } = req.params;
  const user = req.user || {};
    try {
    if (!(user.rol === 'admin' || (user.rol === 'clinica' && Number(user.clinica_id) === Number(id)) || (user.clinica_id && Number(user.clinica_id) === Number(id) && user.dueno))) {
      return res.status(403).json({ error: 'No autorizado' });
    }
    const usuarios = await usuariosModelo.obtenerUsuariosPorClinica(id);
    res.json(usuarios);
  } catch (e) {
    console.error('Error listar usuarios clinica:', e);
    res.status(500).json({ error: 'Error listando usuarios' });
  }
});

router.post('/:id/usuarios', auth, async (req, res) => {
  const { id } = req.params; // clinica id
  const user = req.user || {};
  const { usuario, clave, rol } = req.body;
  if (!usuario || !clave) return res.status(400).json({ error: 'usuario y clave requeridos' });
    try {
    if (!(user.rol === 'admin' || (user.rol === 'clinica' && Number(user.clinica_id) === Number(id)) || (user.clinica_id && Number(user.clinica_id) === Number(id) && user.dueno))) {
      return res.status(403).json({ error: 'No autorizado' });
    }
    // Crear usuario para la clínica; si es admin del sitio, puede crear con rol arbitrario
    const newId = await usuariosModelo.crearUsuarioClinicaAdmin({ usuario, clave, rol: rol || 'doctor', clinica_id: id });
    res.status(201).json({ id: newId });
  } catch (e) {
    console.error('Error crear usuario clinica:', e);
    res.status(500).json({ error: 'Error creando usuario' });
  }
});

router.put('/:id/usuarios/:uid', auth, async (req, res) => {
  const { id, uid } = req.params;
  const user = req.user || {};
  const payload = req.body || {};
    try {
    if (!(user.rol === 'admin' || (user.rol === 'clinica' && Number(user.clinica_id) === Number(id)) || (user.clinica_id && Number(user.clinica_id) === Number(id) && user.dueno))) {
      return res.status(403).json({ error: 'No autorizado' });
    }
    const affected = await usuariosModelo.actualizarUsuario(uid, payload, id);
    res.json({ affected });
  } catch (e) {
    console.error('Error actualizar usuario clinica:', e);
    res.status(500).json({ error: 'Error actualizando usuario' });
  }
});

router.delete('/:id/usuarios/:uid', auth, async (req, res) => {
  const { id, uid } = req.params;
  const user = req.user || {};
  try {
    if (!(user.rol === 'admin' || (user.rol === 'clinica' && Number(user.clinica_id) === Number(id)) || (user.clinica_id && Number(user.clinica_id) === Number(id) && user.dueno))) {
      return res.status(403).json({ error: 'No autorizado' });
    }
    const affected = await usuariosModelo.eliminarUsuario(uid, id);
    res.json({ affected });
  } catch (e) {
    console.error('Error eliminar usuario clinica:', e);
    res.status(500).json({ error: 'Error eliminando usuario' });
  }
});

module.exports = router;
