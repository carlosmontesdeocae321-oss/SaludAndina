const doctorProfilesModelo = require('../modelos/doctorProfilesModelo');
const doctorDocumentsModelo = require('../modelos/doctorDocumentsModelo');
const path = require('path');
const { uploadFile: uploadToCloudinary } = require('../servicios/cloudinaryService');
const { uploadFile: uploadToFirebase } = require('../servicios/firebaseService');
const fs = require('fs');

async function verPerfil(req, res) {
  try {
    const userId = req.params.userId || req.user && req.user.id;
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
    if (!perfil) return res.status(404).json({ message: 'Perfil no encontrado' });
    res.json(perfil);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

async function crearOActualizarPerfil(req, res) {
  try {
    const userId = req.params.userId || (req.user && req.user.id);
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    const existing = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
    // Build payload only with fields explicitly provided to avoid
    // overwriting existing values with undefined/null when the client
    // didn't send them (for example avatar_url when user didn't change image).
    const payload = {};
    // Accept standard fields
    ['nombre','apellido','direccion','telefono','email','bio','avatar_url','especialidad'].forEach((k) => {
      if (Object.prototype.hasOwnProperty.call(req.body, k)) {
        payload[k] = req.body[k];
      }
    });
    // Backwards/forwards compatibility: map alternative keys to `especialidad`
    if (Object.prototype.hasOwnProperty.call(req.body, 'specialty') && !payload.especialidad) {
      payload.especialidad = req.body['specialty'];
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'profesion') && !payload.especialidad) {
      payload.especialidad = req.body['profesion'];
    }
    if (!existing) {
      const id = await doctorProfilesModelo.crearPerfil(userId, payload);
      const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
      return res.status(201).json(perfil);
    } else {
      await doctorProfilesModelo.actualizarPerfil(userId, payload);
      const perfil = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
      return res.json(perfil);
    }
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

// Subir avatar: multipart field 'avatar'
async function subirAvatar(req, res) {
  try {
    const userId = req.params.userId || (req.user && req.user.id);
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    if (!req.file) return res.status(400).json({ message: 'Archivo no recibido en campo avatar' });
    // Subir a Cloudinary o a Firebase (opcional)
    try {
      let url;
      let uploadedToCDN = false;
      if (process.env.USE_FIREBASE_STORAGE === 'true') {
        const dest = `clinica/avatars/${Date.now()}_${req.file.originalname}`;
        const r = await uploadToFirebase(req.file.path, dest);
        url = r.publicUrl;
        uploadedToCDN = true;
      } else {
        // Intentamos subir a Cloudinary (si está configurado)
        try {
          const r = await uploadToCloudinary(req.file.path, { folder: 'clinica/avatars' });
          url = r.secure_url;
          uploadedToCDN = true;
        } catch (uploadErr) {
          console.warn('cloudinary upload failed, falling back to local file:', uploadErr && uploadErr.message ? uploadErr.message : uploadErr);
        }
      }

      // Si la subida a CDN falló, servir el archivo desde la ruta estática local `/uploads/...`
      if (!uploadedToCDN) {
        // El archivo permanece en disk (multer lo guardó). Construir URL pública relativa.
        const filename = req.file.filename || path.basename(req.file.path);
        url = `/uploads/avatars/${filename}`;
      }

      const existing = await doctorProfilesModelo.obtenerPerfilPorUsuario(userId);
      if (!existing) {
        await doctorProfilesModelo.crearPerfil(userId, { avatar_url: url });
      } else {
        await doctorProfilesModelo.actualizarPerfil(userId, { avatar_url: url });
      }
      res.json({ ok: true, avatar_url: url });
    } catch (e) {
      console.error('Error procesando avatar:', e);
      res.status(500).json({ message: err.message || 'Error subiendo avatar' });
    }
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

// Listar documentos asociados a un doctor (public)
async function listarDocumentos(req, res) {
  try {
    const userId = req.params.userId;
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    const docs = await doctorDocumentsModelo.listarDocumentosPorUsuario(userId);
    res.json(docs);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

// Subir múltiples documentos (multipart field 'files')
async function subirDocumentos(req, res) {
  try {
    const userId = req.params.userId || (req.user && req.user.id);
    if (!userId) return res.status(400).json({ message: 'userId es requerido' });
    if (!req.files || req.files.length === 0) return res.status(400).json({ message: 'No se recibieron archivos' });
    const saved = [];
    for (const f of req.files) {
      try {
        let url;
        let uploadedToCDN = false;
        if (process.env.USE_FIREBASE_STORAGE === 'true') {
          const dest = `clinica/documents/${Date.now()}_${f.originalname}`;
          const r = await uploadToFirebase(f.path, dest);
          url = r.publicUrl;
          uploadedToCDN = true;
        } else {
          try {
            const r = await uploadToCloudinary(f.path, { folder: 'clinica/documents' });
            url = r.secure_url;
            uploadedToCDN = true;
          } catch (uploadErr) {
            console.warn('cloudinary document upload failed, falling back to local file:', uploadErr && uploadErr.message ? uploadErr.message : uploadErr);
          }
        }

        if (!uploadedToCDN) {
          const filename = f.filename || path.basename(f.path);
          url = `/uploads/documents/${filename}`;
        }

        const filename = f.originalname;
        await doctorDocumentsModelo.crearDocumento(userId, { filename, path: url, url });
        saved.push({ filename, url });
      } catch (e) {
        console.error('Error subiendo documento', e);
      }
    }
    res.status(201).json({ ok: true, saved });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
}

module.exports = {
  verPerfil,
  crearOActualizarPerfil,
  subirAvatar
  , listarDocumentos, subirDocumentos
};
