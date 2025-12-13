const express = require('express');
const router = express.Router();
const pagosService = require('../servicios/pagosService');
const { auth } = require('../middlewares/auth');
const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const SALT_ROUNDS = 10;
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } });
const { saveDoc, uploadBuffer, sendFCMToTopic } = require('../servicios/firebaseService');
const { resolvePlanFromTitle, assignPlanToClinic, getPlanSpecBySlug } = require('../utils/planHelper');
const usuariosModelo = require('../modelos/usuariosModelo');

// Admin: listar compras pendientes para la clínica del usuario (o todas si rol=admin)
router.get('/admin/list', auth, async (req, res) => {
  try {
    const user = req.user || {};
    // permitir sólo dueños con clinica_id o usuarios con rol 'admin' o cuenta tipo 'clinica'
    if (!user.dueno && user.rol !== 'admin' && user.rol !== 'clinica') {
      return res.status(403).json({ message: 'Acceso no autorizado' });
    }

    const clinicaId = user.clinica_id || null;
    const pagosService = require('../servicios/pagosService');
    const pendientes = await pagosService.listarComprasPendientes({ clinica_id: clinicaId });
    res.json({ ok: true, compras: pendientes });
  } catch (err) {
    console.error('Error admin/list compras:', err);
    res.status(500).json({ ok: false, message: err.message });
  }
});

// Admin: confirmar compra (protegido)
router.post('/admin/confirm', auth, async (req, res) => {
  try {
    const user = req.user || {};
    if (!user.dueno && user.rol !== 'admin' && user.rol !== 'clinica') {
      return res.status(403).json({ message: 'Acceso no autorizado' });
    }
    const { compraId, provider_txn_id } = req.body || {};
    if (!compraId) return res.status(400).json({ message: 'compraId requerido' });
    const pagosService = require('../servicios/pagosService');
    const ok = await pagosService.confirmarCompra({ compraId, provider_txn_id });
    if (!ok) return res.status(404).json({ message: 'Compra no encontrada' });
    res.json({ ok: true, message: 'Compra confirmada' });
  } catch (err) {
    console.error('Error admin/confirm:', err);
    res.status(500).json({ ok: false, message: err.message });
  }
});

// Crear una compra de promoción (permitir anónimo: no requiere auth)
router.post('/crear', async (req, res) => {
  try {
    let usuarioId = req.user?.id;
    const clinicaId = req.user?.clinica_id || req.body.clinica_id || null;
    const { titulo, monto, provider, cantidad } = req.body;
    let metadata = null;
    try {
      if (req.body.metadata && typeof req.body.metadata === 'string') {
        const parsed = JSON.parse(req.body.metadata);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          metadata = parsed;
        }
      } else if (req.body.metadata && typeof req.body.metadata === 'object' && !Array.isArray(req.body.metadata)) {
        metadata = req.body.metadata;
      }
    } catch (e) {
      console.warn('POST /compras_promociones/crear - metadata parse error:', e.message || e);
      metadata = null;
    }
    if (!titulo || monto == null) return res.status(400).json({ message: 'titulo y monto requeridos' });

    // Sólo permitimos compras anónimas para la promoción de Doctor Individual
    const tituloLower = (titulo || '').toString().toLowerCase();
    const isDoctorIndividual = tituloLower.includes('doctor individual');
    // Si no tenemos usuario en req.user, intentar autenticar con headers x-usuario/x-clave
    if (!usuarioId) {
      try {
        const headerUser = req.headers['x-usuario'];
        const headerClave = req.headers['x-clave'];
        if (headerUser && headerClave) {
          const usuariosModelo = require('../modelos/usuariosModelo');
          const user = await usuariosModelo.obtenerUsuarioPorCredenciales(headerUser, headerClave);
          if (user) usuarioId = user.id;
        }
      } catch (e) {
        console.warn('Intento autenticacion por headers falló:', e.message || e);
      }
    }

    if (!usuarioId && !isDoctorIndividual) {
      return res.status(401).json({ message: 'Autenticación requerida para comprar esta promoción' });
    }

    const compra = await pagosService.crearCompraPromocion({
      titulo,
      monto,
      cantidad: cantidad || 1,
      clinica_id: clinicaId,
      usuario_id: usuarioId,
      provider: provider || 'mock',
      metadata,
    });

    // Devolver la url de pago (para mock abrir la ruta interna)
    res.status(201).json({ compraId: compra.id, payment_url: compra.payment_url });
  } catch (err) {
    console.error('Error crear compra promocion:', err);
    res.status(500).json({ message: err.message });
  }
});

// Endpoint que simula la página de checkout del provider (solo para pruebas)
router.get('/mock-pay/:id', async (req, res) => {
  const compraId = req.params.id;
  // Página mínima que simula pagar y llama al backend para confirmar
  const html = `
    <html>
      <body style="font-family: Arial; padding: 20px;">
        <h2>Simulación de pago (Mock)</h2>
        <p>Compra ID: ${compraId}</p>
        <form method="post" action="/api/compras_promociones/confirmar">
          <input type="hidden" name="compraId" value="${compraId}" />
          <button type="submit" style="padding:10px 20px;">Simular pago exitoso</button>
        </form>
      </body>
    </html>
  `;
  res.send(html);
});

// Listar compras del usuario autenticado
router.get('/mis', auth, async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: 'Autenticación requerida' });
    const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE usuario_id = ? ORDER BY creado_en DESC', [userId]);
    res.json(rows);
  } catch (e) {
    console.error('Error listar compras usuario:', e);
    res.status(500).json({ message: 'Error listando compras' });
  }
});

// Confirmar compra (webhook o llamada del frontend después del pago)
router.post('/confirmar', async (req, res) => {
  try {
    const { compraId, provider_txn_id } = req.body;
    if (!compraId) return res.status(400).json({ message: 'compraId requerido' });
    const ok = await pagosService.confirmarCompra({ compraId, provider_txn_id });
    if (!ok) return res.status(404).json({ message: 'Compra no encontrada' });
    res.json({ message: 'Compra confirmada' });
  } catch (err) {
    console.error('Error confirmar compra:', err);
    res.status(500).json({ message: err.message });
  }
});

// Obtener estado de compra
router.get('/:id', auth, async (req, res) => {
  try {
    const compra = await pagosService.obtenerCompra(req.params.id);
    if (!compra) return res.status(404).json({ message: 'Compra no encontrada' });
    res.json(compra);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Guardar datos adicionales asociados a la compra (ej: datos de la clínica)
// Accept optional photo upload plus form fields in cuerpo
router.post('/:id/datos', auth, upload.single('foto'), async (req, res) => {
  try {
    const compraId = req.params.id;
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: 'Autenticación requerida' });
    const [rows] = await pool.query('SELECT usuario_id, status, clinica_id FROM compras_promociones WHERE id = ? LIMIT 1', [compraId]);
    const compraRow = rows && rows[0] ? rows[0] : null;
    if (!compraRow) return res.status(404).json({ message: 'Compra no encontrada' });
    // Sólo el usuario propietario puede actualizar sus datos
    if (compraRow.usuario_id && Number(compraRow.usuario_id) !== Number(userId)) {
      return res.status(403).json({ message: 'No autorizado para actualizar datos de esta compra' });
    }

    // Sólo permitir guardar datos adicionales cuando la compra haya sido confirmada por el admin
    // (evita que compradores rellenen datos antes de la aceptación)
    if ((compraRow.status || '').toString().toLowerCase() !== 'completed') {
      return res.status(403).json({ message: 'La compra no está confirmada. Espera la confirmación del administrador.' });
    }

    // Asegurar columna extra_data
    try {
      await pool.query("ALTER TABLE compras_promociones ADD COLUMN extra_data JSON NULL");
    } catch (e) {
      // ignore if exists or not supported
    }

    // Build payload from multipart fields or JSON body
    let payload = {};
    try {
      // If multipart, fields are in req.body as strings
      payload = Object.assign({}, req.body || {});
    } catch (e) {
      payload = req.body || {};
    }

    // Track if we created/linked a usuario while processing
    let createdUsuarioId = null;

    // If a file was uploaded, try to upload to firebase (or save locally) and set foto_url
    if (req.file) {
      const filename = `compras_promociones/${compraId}/datos_${Date.now()}_${req.file.originalname.replace(/[^a-zA-Z0-9_.-]/g, '_')}`;
      try {
        const upl = await uploadBuffer(req.file.buffer, filename, req.file.mimetype);
        payload.foto_url = upl.publicUrl;
      } catch (e) {
        // fallback local
        try {
          const fs = require('fs');
          const path = require('path');
          const uploadsDir = path.join(__dirname, '..', 'uploads', 'compras_promociones', String(compraId));
          fs.mkdirSync(uploadsDir, { recursive: true });
          const localName = `${Date.now()}_${req.file.originalname.replace(/[^a-zA-Z0-9_.-]/g, '_')}`;
          const localPath = path.join(uploadsDir, localName);
          fs.writeFileSync(localPath, req.file.buffer);
          payload.foto_url = `${req.protocol}://${req.get('host')}/uploads/compras_promociones/${compraId}/${localName}`;
        } catch (e2) {
          console.warn('No se pudo guardar foto en multipart /:id/datos:', e.message || e2.message || e);
        }
      }
    }

    // Debug: log payload early for tracing
    console.log('POST /api/compras_promociones/:id/datos - compraId:', compraId, 'userId:', userId);
    // Normalize empty strings to null for clarity
    Object.keys(payload).forEach(k => {
      if (typeof payload[k] === 'string' && payload[k].trim() === '') payload[k] = null;
    });

    console.log('POST /api/compras_promociones/:id/datos - payload after normalize:', payload);

    // Accept both 'nombre' and 'nombre_clinica' from older clients - normalize to nombre_clinica
    try {
      if (payload.nombre && !payload.nombre_clinica) payload.nombre_clinica = payload.nombre;
      if (payload.direccion && !payload.direccion_clinica) payload.direccion_clinica = payload.direccion;
    } catch (e) {}

    await pool.query('UPDATE compras_promociones SET extra_data = ? WHERE id = ?', [JSON.stringify(payload), compraId]);

    // Guardar en Firestore también si corresponde
    try {
      await saveDoc('compras_promociones', compraId, { extra_data: payload });
    } catch (e) {
      console.warn('No se pudo guardar extra_data en Firestore:', e.message || e);
    }

    // If the compra is already completed (admin accepted) and no clinica was created, create it now using extra_data
    try {
      if (compraRow.status === 'completed' && !compraRow.clinica_id) {
        const compraFull = (await pool.query('SELECT id, titulo, usuario_id, extra_data FROM compras_promociones WHERE id = ? LIMIT 1', [compraId]))[0][0];
        let extra = null;
        try {
          if (compraFull.extra_data) {
            if (typeof compraFull.extra_data === 'string') {
              extra = JSON.parse(compraFull.extra_data);
            } else if (typeof compraFull.extra_data === 'object') {
              extra = compraFull.extra_data;
            }
          }
        } catch (e) { extra = null; }
        const tituloLower = (compraFull.titulo || '').toString().toLowerCase();
        const looksLikeClinic = tituloLower.includes('clinica') || tituloLower.includes('clínica') || (extra && extra.nombre_clinica);
        if (looksLikeClinic) {
          const nombreClinica = (extra && (extra.nombre_clinica || extra.nombre)) ? (extra.nombre_clinica || extra.nombre) : (compraFull.titulo || 'Clínica');
          const direccion = (extra && (extra.direccion || extra.direccion_clinica)) ? (extra.direccion || extra.direccion_clinica) : '';
          // We can create the clinic if either:
          // - extra provides usuario+clave (we will create a new clinic account), or
          // - the compra has a usuario_id (buyer is authenticated) that we'll link as owner.
          // If neither is present, reject.
          const compraHasUsuario = !!compraFull.usuario_id;
          const extraHasCreds = !!(extra && extra.usuario && extra.clave);
          if (!compraHasUsuario && !extraHasCreds) {
            console.log('Cannot create clinic for compra', compraId, '- missing usuario/clave in payload and compra has no usuario_id');
            return res.status(400).json({ message: 'Se requieren campos usuario y clave para crear la clínica, o la compra debe estar asociada a un usuario autenticado' });
          }

          const [cRes] = await pool.query('INSERT INTO clinicas (nombre, direccion) VALUES (?, ?)', [nombreClinica, direccion]);
          const clinicaId = cRes.insertId;
          console.log('Created clinica', clinicaId, 'from compra', compraId, 'nombre:', nombreClinica, 'direccion:', direccion);
          console.log('Proceeding to create clinica and vincular usuario for compra', compraId);
          // Determinar qué usuario vincular.
          // Priorizar si el comprador envió `extra.usuario`: intentamos buscar ese usuario por nombre
          // y si no existe lo creamos. Sólo si no se proporcionó `extra.usuario` usamos compraFull.usuario_id o userId.
          let usuarioParaVincular = null;
          try {
            if (extra && extra.usuario) {
              // Buscar usuario existente por nombre
              const [found] = await pool.query('SELECT id FROM usuarios WHERE usuario = ? LIMIT 1', [extra.usuario]);
              if (found && found[0]) {
                usuarioParaVincular = found[0].id;
                // asegurarnos de marcar como dueño y asignar clinica_id posteriormente
                createdUsuarioId = usuarioParaVincular;
              } else if (extra.clave) {
                // Crear nuevo usuario-clínica usando el modelo
                try {
                  const id = await usuariosModelo.crearUsuarioClinicaAdmin({ usuario: extra.usuario, clave: String(extra.clave), rol: 'clinica', clinica_id: clinicaId });
                  usuarioParaVincular = id;
                  createdUsuarioId = id;
                } catch (e) {
                  console.warn('Error creating usuario via model during POST datos:', e.message || e);
                }
              }
            }
          } catch (e) { console.warn('Error while attempting to resolve/create usuario from extra data:', e.message || e); }

          // Si no se proporcionó usuario en payload, usar usuario de la compra o el user autenticado
          if (!usuarioParaVincular) {
            usuarioParaVincular = compraFull.usuario_id || userId;
          }

          // Si tenemos un usuario para vincular, actualizar su clinica_id.
          // Si el usuario es un `doctor`, lo vinculamos como doctor (dueno = 0)
          // y además creamos un registro en `compras_doctores` para reservar el cupo.
          if (usuarioParaVincular) {
            try {
              // Obtener rol actual del usuario
              const [urows] = await pool.query('SELECT rol FROM usuarios WHERE id = ? LIMIT 1', [usuarioParaVincular]);
              const urow = urows && urows[0] ? urows[0] : null;
              const rolActual = urow ? (urow.rol || '').toString().toLowerCase() : '';

              if (rolActual === 'doctor' || rolActual === 'medico') {
                // Vincular como doctor (no dueño)
                await pool.query('UPDATE usuarios SET clinica_id = ?, dueno = 0 WHERE id = ?', [clinicaId, usuarioParaVincular]);
                // Asegurar existencia de tabla compras_doctores
                try {
                  await pool.query(`
                    CREATE TABLE IF NOT EXISTS compras_doctores (
                      id INT AUTO_INCREMENT PRIMARY KEY,
                      usuario_id INT NOT NULL,
                      clinica_id INT NOT NULL,
                      compra_id INT DEFAULT NULL,
                      creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ) ENGINE=InnoDB;
                  `);
                } catch (e) {
                  console.warn('No se pudo asegurar tabla compras_doctores:', e.message || e);
                }
                // Insertar reserva en compras_doctores
                try {
                  await pool.query('INSERT INTO compras_doctores (usuario_id, clinica_id, compra_id) VALUES (?, ?, ?)', [usuarioParaVincular, clinicaId, compraId]);
                } catch (e) {
                  console.warn('No se pudo insertar en compras_doctores:', e.message || e);
                }
                console.log('Linked doctor usuario', usuarioParaVincular, 'to clinica', clinicaId, 'and created compras_doctores entry');
              } else {
                // Para otros roles (por ejemplo cuenta tipo `clinica`) marcamos como dueño
                await pool.query('UPDATE usuarios SET clinica_id = ?, dueno = 1 WHERE id = ?', [clinicaId, usuarioParaVincular]);
                console.log('Linked usuario', usuarioParaVincular, 'to clinica', clinicaId, 'as owner');
              }

              if (!createdUsuarioId) createdUsuarioId = usuarioParaVincular;
            } catch (e) { console.warn('Failed to link usuario to clinica in POST datos:', e.message || e); }
          }

          try { await pool.query('UPDATE compras_promociones SET clinica_id = ? WHERE id = ?', [clinicaId, compraId]); } catch (e) { console.warn('Failed to update compra with clinica_id in POST datos:', e.message || e); }

          const planSpec = resolvePlanFromTitle(compraFull.titulo || '') || getPlanSpecBySlug('clinica_pequena');
          if (planSpec) {
            try {
              await assignPlanToClinic({ clinicaId, planSpec });
              const planPayload = {
                plan_aplicado: {
                  slug: planSpec.slug,
                  nombre: planSpec.nombre,
                  clinica_id: clinicaId,
                  aplicado_en: new Date().toISOString(),
                }
              };
              try {
                await pool.query(
                  'UPDATE compras_promociones SET extra_data = JSON_MERGE_PATCH(COALESCE(extra_data, JSON_OBJECT()), CAST(? AS JSON)) WHERE id = ?',
                  [JSON.stringify(planPayload), compraId]
                );
              } catch (mergeErr) {
                try {
                  await pool.query(
                    "UPDATE compras_promociones SET extra_data = JSON_SET(COALESCE(extra_data, '{}'), '$.plan_aplicado', CAST(? AS JSON)) WHERE id = ?",
                    [JSON.stringify(planPayload.plan_aplicado), compraId]
                  );
                } catch (fallbackErr) {
                  console.warn('No se pudo registrar plan_aplicado en extra_data durante POST datos:', fallbackErr.message || fallbackErr);
                }
              }
              try {
                await saveDoc('compras_promociones', compraId, { plan_aplicado: planPayload.plan_aplicado });
              } catch (fireErr) {
                console.warn('No se pudo sincronizar plan_aplicado en Firestore (POST datos):', fireErr.message || fireErr);
              }
            } catch (assignErr) {
              console.warn('Error asignando plan a la clínica desde POST datos:', assignErr.message || assignErr);
            }
          }

          // Devolver usuarioId creado o vinculado en la respuesta para que el cliente pueda notificar al usuario
          // (no es mandatorio, pero útil)
        }
      }
    } catch (e) {
      console.warn('Error while processing clinic creation on POST datos:', e.message || e);
    }

    const resp = { ok: true };
    if (createdUsuarioId) resp.usuarioId = createdUsuarioId;
    res.json(resp);
  } catch (e) {
    console.error('Error saving compra extra data', e);
    res.status(500).json({ message: 'Error al guardar datos' });
  }
});

// Crear clínica y usuario admin tras compra (permitir anónimo: no requiere auth)
router.post('/crear-clinica', async (req, res) => {
    const { nombre, direccion, usuario, clave } = req.body;
  if (!nombre || !usuario || !clave) return res.status(400).json({ message: 'Faltan datos' });
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [cRes] = await conn.query('INSERT INTO clinicas (nombre, direccion) VALUES (?, ?)', [nombre, direccion || '']);
    const clinicaId = cRes.insertId;
    // Hash the password before storing to avoid plain-text passwords
    const hashed = await bcrypt.hash(clave, SALT_ROUNDS);
    // Crear el usuario con rol 'doctor' y marcarlo como dueño (dueno=1).
    // Así evitamos valores inesperados en la columna `rol` y mantenemos la distinción
    // de dueño mediante el flag `dueno`.
    const [uRes] = await conn.query('INSERT INTO usuarios (usuario, clave, rol, clinica_id, dueno) VALUES (?, ?, ?, ?, 1)', [usuario, hashed, 'clinica', clinicaId]);
    // Intentar asignar un plan por defecto a la clínica para que tenga límites iniciales.
    // POR QUÉ: usamos la misma conexión `conn` dentro de la transacción para evitar bloqueos
    // causados por mezclar la transacción con consultas que abren nuevas conexiones.
    // Buscamos un plan "Clínica Pequeña" en la tabla `planes` usando la misma conexión.
    let planId = null;
    const [pRows] = await conn.query('SELECT id, nombre, pacientes_max, doctores_max FROM planes');
    let found = null;
    if (pRows && pRows.length > 0) {
      found = pRows.find(p => (p.nombre || '').toLowerCase().includes('peque') || (p.nombre || '').toLowerCase().includes('pequeña'));
    }
    if (found) {
      planId = found.id;
    } else {
      const [pIns] = await conn.query(
        'INSERT INTO planes (nombre, precio, pacientes_max, doctores_max, sucursales_incluidas, descripcion) VALUES (?, ?, ?, ?, ?, ?)',
        ['Clínica Pequeña', 20.0, 100, 2, 0, 'Plan por defecto creado automáticamente (100 pacientes, 2 doctores)']
      );
      planId = pIns.insertId;
    }
    // Insertar registro en clinica_planes usando la misma conexión/tx
    await conn.query(
      'INSERT INTO clinica_planes (clinica_id, plan_id, fecha_inicio, fecha_fin, activo) VALUES (?, ?, ?, ?, ?)',
      [clinicaId, planId, new Date(), null, 1]
    );
    await conn.commit();
    // Intentar crear también documentos en Firestore para sincronizar inmediatamente
    try {
      // Guardar clínica mínima en Firestore
      await saveDoc('clinics', clinicaId, { nombre: nombre || null, direccion: direccion || null });
      // Guardar usuario en Firestore como doctor individual dueño de la clínica
      await saveDoc('users', uRes.insertId, { usuario: usuario, rol: 'doctor', clinicaId: clinicaId, dueno: true });
    } catch (e) {
      console.warn('Warning: failed to save clinica/usuario to Firestore on crear-clinica:', e.message || e);
    }
    res.status(201).json({ clinicaId, usuarioId: uRes.insertId });
  } catch (err) {
    await conn.rollback();
    console.error('Error crear clinica+usuario:', err);
    res.status(500).json({ message: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;

// Ruta pública para subir comprobante asociado a una compra de promoción
// Permite que usuarios no autenticados suban su comprobante tras crear la compra.
router.post('/:id/comprobante', upload.single('comprobante'), async (req, res) => {
  try {
    const compraId = req.params.id;
    if (!req.file) return res.status(400).json({ error: 'Imagen del comprobante requerida' });

    // Guardar archivo en Firebase Storage (o en el storage configurado).
    // Si Firebase no está disponible, guardamos localmente en ./uploads.
    const filename = `compras_promociones/${compraId}/${Date.now()}_${req.file.originalname.replace(/[^a-zA-Z0-9_.-]/g, '_')}`;
    let uploadRes = null;
    try {
      uploadRes = await uploadBuffer(req.file.buffer, filename, req.file.mimetype);
    } catch (e) {
      console.warn('uploadBuffer falló, guardando localmente:', e.message || e);
      // Guardar en carpeta uploads/compras_promociones/{compraId}/
      const fs = require('fs');
      const path = require('path');
      const uploadsDir = path.join(__dirname, '..', 'uploads', 'compras_promociones', String(compraId));
      try {
        fs.mkdirSync(uploadsDir, { recursive: true });
      } catch (mkdirErr) {
        console.warn('No se pudo crear uploads dir:', mkdirErr.message || mkdirErr);
      }
      const localName = `${Date.now()}_${req.file.originalname.replace(/[^a-zA-Z0-9_.-]/g, '_')}`;
      const localPath = path.join(uploadsDir, localName);
      try {
        fs.writeFileSync(localPath, req.file.buffer);
        // Construir URL pública relativa
        const publicUrl = `${req.protocol}://${req.get('host')}/uploads/compras_promociones/${compraId}/${localName}`;
        uploadRes = { publicUrl, path: `compras_promociones/${compraId}/${localName}` };
      } catch (writeErr) {
        console.error('Error guardando comprobante localmente:', writeErr.message || writeErr);
        return res.status(500).json({ error: 'Error al procesar comprobante' });
      }
    }

    // Intentar añadir columna comprobante_url si no existe (ignorar error si ya existe)
    try {
      await pool.query('ALTER TABLE compras_promociones ADD COLUMN comprobante_url TEXT NULL');
    } catch (e) {
      // ignore - columna ya existe probablemente
    }

    // Actualizar registro de la compra con la URL del comprobante y dejar en estado 'pending'
    const [r] = await pool.query('UPDATE compras_promociones SET comprobante_url = ?, status = ? WHERE id = ?', [uploadRes.publicUrl, 'pending', compraId]);

    // Además, crear una entrada en la tabla `pagos` para que el admin la vea
    try {
      // Intentar obtener usuario, monto y título asociados a la compra (si existe)
      const [rows] = await pool.query('SELECT usuario_id, monto, titulo FROM compras_promociones WHERE id = ? LIMIT 1', [compraId]);
      const compraRow = rows && rows[0] ? rows[0] : null;
      const usuarioId = compraRow ? compraRow.usuario_id || null : null;
      const compraMonto = compraRow ? compraRow.monto : null;
      const compraTitulo = compraRow ? compraRow.titulo : null;
      // Asegurar que la tabla `pagos` existe antes de insertar
      try {
        await pool.query(`
          CREATE TABLE IF NOT EXISTS pagos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            producto_id INT DEFAULT NULL,
            monto DECIMAL(10,2) DEFAULT NULL,
            imagen_url TEXT,
            estado VARCHAR(32) DEFAULT 'pending',
            creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          ) ENGINE=InnoDB;
        `);
      } catch (e) {
        console.warn('No se pudo asegurar tabla pagos:', e.message || e);
      }

      // Insertar en pagos: guardamos user_id, producto_id (compraId), monto real de la compra y la imagen
      const [pRes] = await pool.query('INSERT INTO pagos (user_id, producto_id, monto, imagen_url, estado) VALUES (?, ?, ?, ?, ?)', [usuarioId, compraId, compraMonto || null, uploadRes.publicUrl, 'pending']);
      const pagoId = pRes.insertId;
      // Intentar crear mirror en Firestore para pagos
      try {
        await saveDoc('payments', String(pagoId), { userId: usuarioId ? Number(usuarioId) : null, productoId: Number(compraId), monto: compraMonto ? Number(compraMonto) : null, imagen_url: uploadRes.publicUrl, estado: 'pending', titulo: compraTitulo || null, createdAt: new Date().toISOString() });
      } catch (e) {
        console.warn('No se pudo guardar payment en Firestore (fallback from compra comprobante):', e.message || e);
      }
    } catch (e) {
      console.warn('No se pudo crear fila en pagos desde comprobante de compra:', e.message || e);
    }

    // Actualizar copia en Firestore si está configurada
    try {
      await saveDoc('compras_promociones', compraId, { comprobante_url: uploadRes.publicUrl, status: 'pending' });
    } catch (e) {
      console.warn('No se pudo actualizar compra_promociones en Firestore:', e.message || e);
    }

    // Notificar a admins por topic
    try {
      await sendFCMToTopic('admins', {
        notification: { title: 'Nuevo comprobante de compra', body: `Compra ${compraId} tiene nuevo comprobante.` },
        data: { compraId: String(compraId) }
      });
    } catch (e) {
      console.warn('FCM notify admins failed:', e.message || e);
    }

    return res.status(200).json({ ok: true, url: uploadRes.publicUrl });
  } catch (err) {
    console.error('Error subir comprobante compra:', err);
    return res.status(500).json({ error: 'Error al procesar comprobante' });
  }
});
