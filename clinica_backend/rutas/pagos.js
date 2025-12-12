const express = require('express');
const router = express.Router();
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 6 * 1024 * 1024 } });
const pool = require('../config/db');
const { uploadBuffer, saveDoc, sendFCMToTopic, sendFCMToTokens } = require('../servicios/firebaseService');
const pagosService = require('../servicios/pagosService');
const { auth } = require('../middlewares/auth');

async function ensureTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS pagos (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NULL,
      producto_id INT DEFAULT NULL,
      monto DECIMAL(10,2) DEFAULT NULL,
      imagen_url TEXT,
      estado VARCHAR(32) DEFAULT 'pending',
      creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;
  `);
  // Ensure column allows NULL (in case table was created previously with NOT NULL)
  try {
    await pool.query('ALTER TABLE pagos MODIFY COLUMN user_id INT NULL');
  } catch (e) {
    // ignore - if modify fails, not critical
    console.warn('ensureTable: ALTER TABLE pagos MODIFY COLUMN user_id INT NULL ->', e.message || e);
  }
}

// Solicitar pago: multipart/form-data con campo 'comprobante' (imagen)
router.post('/solicitar', upload.single('comprobante'), async (req, res) => {
  try {
    const { userId, productoId, monto } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId requerido' });
    if (!req.file) return res.status(400).json({ error: 'Imagen del comprobante requerida' });

    await ensureTable();

    const filename = `payments/${userId}/${Date.now()}_${req.file.originalname.replace(/[^a-zA-Z0-9_.-]/g, '_')}`;
    const uploadRes = await uploadBuffer(req.file.buffer, filename, req.file.mimetype);

    const [result] = await pool.query('INSERT INTO pagos (user_id, producto_id, monto, imagen_url, estado) VALUES (?, ?, ?, ?, ?)', [userId, productoId || null, monto || null, uploadRes.publicUrl, 'pending']);
    const pagoId = result.insertId;

    // Firestore mirror
    try {
      await saveDoc('payments', String(pagoId), {
        userId: Number(userId),
        productoId: productoId ? Number(productoId) : null,
        monto: monto ? Number(monto) : null,
        imagen_url: uploadRes.publicUrl,
        estado: 'pending',
        createdAt: new Date().toISOString()
      });
    } catch (e) {
      console.warn('No se pudo guardar payment en Firestore:', e.message || e);
    }

    // Notificar admins por tópico 'admins'
    try {
      await sendFCMToTopic('admins', {
        notification: { title: 'Nueva solicitud de pago', body: `Usuario ${userId} subió un comprobante.` },
        data: { pagoId: String(pagoId) }
      });
    } catch (e) {
      console.warn('FCM topic send failed', e.message || e);
    }

    res.status(201).json({ ok: true, pagoId, imagen_url: uploadRes.publicUrl });
  } catch (err) {
    console.error('Error /pagos/solicitar', err);
    res.status(500).json({ error: 'Error al crear solicitud de pago' });
  }
});

// Listar pagos (filter by estado) - protegido: admin o dueño de clínica
router.get('/', auth, async (req, res) => {
  try {
    await ensureTable();
    const estado = req.query.estado || null;
    let rows;
    const user = req.user || {};
    // Admin sees everything
    if (user.rol === 'admin') {
      if (estado) {
        [rows] = await pool.query(
          `SELECT p.id, p.user_id, p.producto_id,
             COALESCE(p.monto,
               (SELECT monto FROM compras_pacientes WHERE id = p.producto_id LIMIT 1),
               (SELECT monto FROM compras_promociones WHERE id = p.producto_id LIMIT 1)
             ) AS monto,
             p.imagen_url, p.estado, p.creado_en,
             COALESCE(
               (SELECT titulo FROM compras_promociones WHERE id = p.producto_id LIMIT 1),
               (SELECT 'Cupo para paciente' FROM compras_pacientes WHERE id = p.producto_id LIMIT 1)
             ) AS producto_titulo
           FROM pagos p
           WHERE p.estado = ?
           ORDER BY p.creado_en DESC`,
          [estado]
        );
      } else {
        [rows] = await pool.query(
          `SELECT p.id, p.user_id, p.producto_id,
             COALESCE(p.monto,
               (SELECT monto FROM compras_pacientes WHERE id = p.producto_id LIMIT 1),
               (SELECT monto FROM compras_promociones WHERE id = p.producto_id LIMIT 1)
             ) AS monto,
             p.imagen_url, p.estado, p.creado_en,
             COALESCE(
               (SELECT titulo FROM compras_promociones WHERE id = p.producto_id LIMIT 1),
               (SELECT 'Cupo para paciente' FROM compras_pacientes WHERE id = p.producto_id LIMIT 1)
             ) AS producto_titulo
           FROM pagos p
           ORDER BY p.creado_en DESC`
        );
      }
    } else if (user.clinica_id && (user.dueno || user.rol === 'clinica')) {
      // Clinic owner (owner flag or clinic-role account): show pagos for purchases of this clinic or pagos uploaded by this user
      const clinicaId = user.clinica_id;
      if (estado) {
        [rows] = await pool.query(
          `SELECT p.id, p.user_id, p.producto_id,
             COALESCE(p.monto,
               (SELECT monto FROM compras_pacientes WHERE id = p.producto_id LIMIT 1),
               (SELECT monto FROM compras_promociones WHERE id = p.producto_id LIMIT 1)
             ) AS monto,
             p.imagen_url, p.estado, p.creado_en,
             COALESCE(
               (SELECT titulo FROM compras_promociones WHERE id = p.producto_id LIMIT 1),
               (SELECT 'Cupo para paciente' FROM compras_pacientes WHERE id = p.producto_id LIMIT 1)
             ) AS producto_titulo
           FROM pagos p
           WHERE p.estado = ? AND (
             (SELECT clinica_id FROM compras_promociones WHERE id = p.producto_id LIMIT 1) = ?
             OR p.user_id = ?
           )
           ORDER BY p.creado_en DESC`,
          [estado, clinicaId, user.id]
        );
      } else {
        [rows] = await pool.query(
          `SELECT p.id, p.user_id, p.producto_id,
             COALESCE(p.monto,
               (SELECT monto FROM compras_pacientes WHERE id = p.producto_id LIMIT 1),
               (SELECT monto FROM compras_promociones WHERE id = p.producto_id LIMIT 1)
             ) AS monto,
             p.imagen_url, p.estado, p.creado_en,
             COALESCE(
               (SELECT titulo FROM compras_promociones WHERE id = p.producto_id LIMIT 1),
               (SELECT 'Cupo para paciente' FROM compras_pacientes WHERE id = p.producto_id LIMIT 1)
             ) AS producto_titulo
           FROM pagos p
           WHERE (
             (SELECT clinica_id FROM compras_promociones WHERE id = p.producto_id LIMIT 1) = ?
             OR p.user_id = ?
           )
           ORDER BY p.creado_en DESC`,
          [clinicaId, user.id]
        );
      }
    } else {
      return res.status(403).json({ error: 'No autorizado' });
    }
    console.log('===> Pagos GET -> filas encontradas:', rows && rows.length ? rows.length : 0);
    if (rows && rows.length > 0) console.log('===> Ejemplo fila[0]:', rows[0]);
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error al listar pagos' });
  }
});

// Actualizar estado (aceptar/rechazar) - admin o dueño de clínica
router.patch('/:id/estado', auth, async (req, res) => {
  try {
    const pagoId = req.params.id;
    const { estado } = req.body; // expected: 'accepted'|'rejected'
    if (!['accepted', 'rejected', 'pending'].includes(estado)) return res.status(400).json({ error: 'Estado inválido' });
    await ensureTable();
    // Authorization: only admin or clinic owner can change status
    const user = req.user || {};
    if (!(user.rol === 'admin' || user.dueno || user.rol === 'clinica')) return res.status(403).json({ error: 'No autorizado' });
    const [result] = await pool.query('UPDATE pagos SET estado = ? WHERE id = ?', [estado, pagoId]);

    try {
      await saveDoc('payments', String(pagoId), { estado });
    } catch (e) {
      console.warn('Failed to update payment in Firestore', e.message || e);
    }

    // notify user via topic `user_<userId>` or tokens if you store them
    try {
      const [[row]] = await pool.query('SELECT user_id, producto_id FROM pagos WHERE id = ? LIMIT 1', [pagoId]);
      const userTopic = `user_${row.user_id}`;

      // If the pago is accepted and linked to a compra, mark the compra as completed
      let compraIdToConfirm = null;
      if (estado === 'accepted' && row.producto_id) {
        try {
          await pool.query('UPDATE compras_promociones SET status = ? WHERE id = ?', ['completed', row.producto_id]);
        } catch (e) {
          console.warn('Failed to mark compra_promociones as completed:', e.message || e);
        }
        compraIdToConfirm = row.producto_id;

        // NOTA: La creación de la clínica se delega a POST /compras_promociones/:id/datos
        // cuando el comprador completa los datos. Aquí sólo marcamos la compra como
        // 'completed' y notificamos al usuario para que complete sus datos.
      }

      // Send notification to the user's topic and include action to complete extra data if accepted
      const notifData = { pagoId: String(pagoId), estado };
      const notifPayload = {
        notification: { title: 'Estado de pago actualizado', body: `Tu comprobante fue ${estado}.` },
        data: notifData
      };
      // If accepted and linked to a compra, add action flag
      if (estado === 'accepted' && row.producto_id) {
        notifPayload.data['action'] = 'completar_datos';
        notifPayload.data['compraId'] = String(row.producto_id);
      }

      await sendFCMToTopic(userTopic, notifPayload);

      if (estado === 'accepted' && compraIdToConfirm) {
        try {
          await pagosService.confirmarCompra({
            compraId: compraIdToConfirm,
            provider_txn_id: `pago-${pagoId}`
          });
        } catch (e) {
          console.warn('Failed to auto-confirm compra after pago acceptance', e.message || e);
        }
      }
    } catch (e) {
      console.warn('Failed to notify user about pago status', e.message || e);
    }

    res.json({ ok: true, affectedRows: result.affectedRows });
  } catch (e) {
    console.error('Error actualizar estado pago', e);
    res.status(500).json({ error: 'Error al actualizar estado' });
  }
});

module.exports = router;
