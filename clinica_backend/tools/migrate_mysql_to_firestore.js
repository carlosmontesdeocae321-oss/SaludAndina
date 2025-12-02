/**
 * Script de migración MySQL -> Firestore (ejecución local)
 * - Requiere que `clinica_backend/config/...` contenga la service account o que
 *   hayas definido GOOGLE_APPLICATION_CREDENTIALS.
 * - Ejecutar desde `clinica_backend` con: `node tools/migrate_mysql_to_firestore.js`
 *
 * Nota: Este script es idempotente y hace commits por lotes para evitar límites.
 */

const fs = require('fs');
const path = require('path');
const { newBatch, commitBatch, saveDoc } = require('../servicios/firebaseService');
const pool = require('../config/db');
const { uploadFile, uploadBuffer } = require('../servicios/firebaseService');

function log(...args) {
  console.log('[migrate]', ...args);
}

const DRY_RUN = process.argv.includes('--dry-run') || process.env.DRY_RUN === '1';

async function migrateUsuarios() {
  log('Migrando usuarios...');
  const [rows] = await pool.query('SELECT id, usuario, rol, clinica_id, dueno, creado_en FROM usuarios');
  if (!rows || rows.length === 0) {
    log('No se encontraron usuarios.');
    return;
  }

  const batchLimit = 400; // Firestore limite por batch (500)
  let batch = newBatch();
  let count = 0;
  for (const r of rows) {
    const docRef = `users/${r.id}`;
    const data = {
      usuario: r.usuario,
      rol: r.rol,
      clinicaId: r.clinica_id || null,
      dueno: r.dueno === 1 || r.dueno === true,
      creado_en: r.creado_en
    };
    // Usar helper simple -> saveDoc (merge)
    try {
      if (DRY_RUN) {
        log('[dry-run] guardar usuario', r.id, data);
      } else {
        await saveDoc('users', r.id, data);
      }
    } catch (e) {
      console.error('Error guardando usuario', r.id, e.message || e);
    }
    count++;
    if (count % batchLimit === 0) {
      log('Usuarios migrados:', count);
    }
  }
  log('Usuarios migrados: total', count);
}

async function migrateClinicas() {
  log('Migrando clinicas...');
  const [rows] = await pool.query('SELECT id, nombre, direccion, imagen_url, telefono_contacto FROM clinicas');
  if (!rows || rows.length === 0) {
    log('No se encontraron clínicas.');
    return;
  }
  for (const r of rows) {
    try {
      const payload = {
        nombre: r.nombre,
        direccion: r.direccion,
        imagen_url: r.imagen_url,
        telefono_contacto: r.telefono_contacto
      };
      if (DRY_RUN) {
        log('[dry-run] guardar clinica', r.id, payload);
      } else {
        await saveDoc('clinics', r.id, payload);
      }
    } catch (e) {
      console.error('Error guardando clinica', r.id, e.message || e);
    }
  }
  log('Clínicas migradas:', rows.length);
}

async function migratePacientes() {
  log('Migrando pacientes...');
  const [rows] = await pool.query('SELECT * FROM pacientes');
  if (!rows || rows.length === 0) {
    log('No se encontraron pacientes.');
    return;
  }
  let count = 0;
  for (const r of rows) {
    const payload = {
      nombres: r.nombres,
      apellidos: r.apellidos,
      cedula: r.cedula,
      telefono: r.telefono,
      direccion: r.direccion,
      doctorId: r.doctor_id || null,
      clinicaId: r.clinica_id || null,
      creado_en: r.creado_en
    };
    try {
      if (DRY_RUN) {
        log('[dry-run] guardar paciente', r.id, payload);
      } else {
        await saveDoc('patients', r.id, payload);
      }
    } catch (e) {
      console.error('Error guardando paciente', r.id, e.message || e);
    }
    count++;
  }
  log('Pacientes migrados:', count);
}

async function migrateCitas() {
  log('Migrando citas...');
  const [rows] = await pool.query('SELECT * FROM citas');
  if (!rows || rows.length === 0) {
    log('No se encontraron citas.');
    return;
  }
  let count = 0;
  for (const c of rows) {
    const payload = {
      pacienteId: c.paciente_id,
      fecha: c.fecha,
      hora: c.hora,
      motivo: c.motivo,
      estado: c.estado,
      clinicaId: c.clinica_id || null,
      creado_en: c.created_at || null
    };
    try {
      if (DRY_RUN) {
        log('[dry-run] guardar cita', c.id, payload);
      } else {
        await saveDoc('appointments', c.id, payload);
      }
    } catch (e) {
      console.error('Error guardando cita', c.id, e.message || e);
    }
    count++;
  }
  log('Citas migradas:', count);
}

async function migrateHistorial() {
  log('Migrando historial (registros clínicos con imágenes)...');
  const [rows] = await pool.query('SELECT h.* FROM historial h');
  if (!rows || rows.length === 0) {
    log('No se encontraron registros de historial.');
    return;
  }
  let count = 0;
  for (const h of rows) {
    let imagenes = [];
    try {
      imagenes = h.imagenes ? JSON.parse(h.imagenes) : [];
    } catch (e) {
      imagenes = [];
    }
    const uploaded = [];
    for (const imgPath of imagenes) {
      // imgPath puede ser '/uploads/historial/xxx' o 'uploads/historial/xxx'
      const rel = imgPath.startsWith('/') ? imgPath.slice(1) : imgPath;
      const abs = path.join(__dirname, '..', rel.replace(/\//g, path.sep));
      if (fs.existsSync(abs)) {
        try {
          if (DRY_RUN) {
            log('[dry-run] subir archivo historial', abs);
            uploaded.push(imgPath);
          } else {
            const dest = `historial/${path.basename(abs)}`;
            const res = await uploadFile(abs, dest);
            uploaded.push(res.publicUrl || (`/` + rel));
          }
        } catch (e) {
          console.error('Error subiendo imagen', abs, e.message || e);
          uploaded.push(imgPath);
        }
      } else {
        console.warn('Archivo no encontrado, se preserva ruta:', abs);
        uploaded.push(imgPath);
      }
    }

    const payload = {
      pacienteId: h.paciente_id,
      motivo_consulta: h.motivo_consulta,
      diagnostico: h.diagnostico,
      tratamiento: h.tratamiento,
      receta: h.receta,
      fecha: h.fecha,
      imagenes: uploaded
    };
    try {
      if (DRY_RUN) {
        log('[dry-run] guardar historial', h.id, payload);
      } else {
        await saveDoc('medical_history', h.id, payload);
      }
    } catch (e) {
      console.error('Error guardando historial', h.id, e.message || e);
    }
    count++;
  }
  log('Historial migrado: total', count);
}

async function migrateDoctorProfiles() {
  log('Migrando doctor_profiles (avatars)...');
  const [rows] = await pool.query('SELECT * FROM doctor_profiles');
  if (!rows || rows.length === 0) {
    log('No se encontraron doctor_profiles.');
    return;
  }
  let count = 0;
  for (const r of rows) {
    const avatar = r.avatar_url;
    let avatarUrl = avatar;
    if (avatar) {
      const rel = avatar.startsWith('/') ? avatar.slice(1) : avatar;
      const abs = path.join(__dirname, '..', rel.replace(/\//g, path.sep));
      if (fs.existsSync(abs)) {
        try {
          if (DRY_RUN) {
            log('[dry-run] subir avatar', abs);
            avatarUrl = avatar;
          } else {
            const dest = `avatars/${path.basename(abs)}`;
            const res = await uploadFile(abs, dest);
            avatarUrl = res.publicUrl || (`/` + rel);
          }
        } catch (e) {
          console.error('Error subiendo avatar', abs, e.message || e);
          avatarUrl = avatar;
        }
      } else {
        console.warn('Avatar no encontrado, preservando ruta:', abs);
      }
    }

    const payload = {
      userId: r.user_id,
      nombre: r.nombre,
      apellido: r.apellido,
      telefono: r.telefono,
      email: r.email,
      bio: r.bio,
      avatar_url: avatarUrl,
      especialidad: r.especialidad
    };
    try {
      if (DRY_RUN) {
        log('[dry-run] guardar doctor_profile', r.user_id, payload);
      } else {
        await saveDoc('doctor_profiles', r.user_id, payload);
      }
    } catch (e) {
      console.error('Error guardando doctor_profile', r.user_id, e.message || e);
    }
    count++;
  }
  log('doctor_profiles migrados:', count);
}

async function migrateDoctorDocuments() {
  log('Migrando doctor_documents (archivos)...');
  const [rows] = await pool.query('SELECT id, user_id, filename, path, url, creado_en FROM doctor_documents');
  if (!rows || rows.length === 0) {
    log('No se encontraron doctor_documents.');
    return;
  }
  let count = 0;
  for (const d of rows) {
    let fileUrl = d.url || d.path || d.filename;
    if (d.path) {
      const rel = d.path.startsWith('/') ? d.path.slice(1) : d.path;
      const abs = path.join(__dirname, '..', rel.replace(/\//g, path.sep));
      if (fs.existsSync(abs)) {
        try {
          if (DRY_RUN) {
            log('[dry-run] subir documento', abs);
            fileUrl = d.path;
          } else {
            const dest = `doctor_documents/${d.user_id}_${path.basename(abs)}`;
            const res = await uploadFile(abs, dest);
            fileUrl = res.publicUrl || (`/` + rel);
          }
        } catch (e) {
          console.error('Error subiendo documento', abs, e.message || e);
        }
      } else {
        console.warn('Documento no encontrado, preservando ruta:', abs);
      }
    }

    const payload = {
      userId: d.user_id,
      filename: d.filename,
      url: fileUrl,
      creado_en: d.creado_en
    };
    try {
      if (DRY_RUN) {
        log('[dry-run] guardar doctor_document', d.id, payload);
      } else {
        await saveDoc('doctor_documents', d.id, payload);
      }
    } catch (e) {
      console.error('Error guardando doctor_document', d.id, e.message || e);
    }
    count++;
  }
  log('doctor_documents migrados:', count);
}

async function migrateClinicImages() {
  log('Migrando imágenes de clinicas...');
  const [rows] = await pool.query('SELECT id, imagen_url FROM clinicas');
  if (!rows || rows.length === 0) {
    log('No se encontraron clinicas con imágenes.');
    return;
  }
  let count = 0;
  for (const r of rows) {
    const img = r.imagen_url;
    let imgUrl = img;
    if (img) {
      const rel = img.startsWith('/') ? img.slice(1) : img;
      const abs = path.join(__dirname, '..', rel.replace(/\//g, path.sep));
      if (fs.existsSync(abs)) {
        try {
          if (DRY_RUN) {
            log('[dry-run] subir imagen clinica', abs);
            imgUrl = img;
          } else {
            const dest = `clinicas/${path.basename(abs)}`;
            const res = await uploadFile(abs, dest);
            imgUrl = res.publicUrl || (`/` + rel);
            await saveDoc('clinics', r.id, { imagen_url: imgUrl });
          }
        } catch (e) {
          console.error('Error subiendo imagen clinica', abs, e.message || e);
        }
      } else {
        console.warn('Imagen clinica no encontrada, preservando ruta:', abs);
      }
    }
    count++;
  }
  log('Imágenes de clinicas procesadas:', count);
}

async function run() {
  try {
    log('Iniciando migración a Firestore');
    await migrateUsuarios();
    await migrateClinicas();
    await migratePacientes();
    await migrateCitas();
    await migrateHistorial();
    await migrateDoctorProfiles();
    await migrateDoctorDocuments();
    await migrateClinicImages();
    log('Migración completa (usuarios, clinicas, pacientes, citas, historial, doctor_profiles, doctor_documents, clinicas imágenes).');
    log('Nota: este script es un punto de partida. Añade migración de pacientes, citas y documentos según necesidad.');
  } catch (e) {
    console.error('Error en migración:', e);
  } finally {
    process.exit(0);
  }
}

run();
