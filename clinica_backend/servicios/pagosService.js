const pool = require('../config/db');

// Servicio de pagos modular: actualmente soporta provider 'mock'.
// La idea es centralizar la integración con Stripe/PayU/MercadoPago en este archivo.

async function ensureTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS compras_promociones (
      id INT AUTO_INCREMENT PRIMARY KEY,
      titulo VARCHAR(255),
      monto DECIMAL(10,2),
      cantidad INT DEFAULT 1,
      clinica_id INT DEFAULT NULL,
      usuario_id INT DEFAULT NULL,
      status VARCHAR(32) DEFAULT 'pending',
      provider VARCHAR(64),
      provider_txn_id VARCHAR(255) DEFAULT NULL,
      creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;
  `);
  // Ensure columna 'cantidad' existe en instalaciones previas
  try {
    await pool.query("ALTER TABLE compras_promociones ADD COLUMN cantidad INT DEFAULT 1");
  } catch (e) {
    // ignore if column already exists or ALTER not permitted
  }
}

async function ensureAplicacionesTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS compras_promociones_aplicaciones (
      id INT AUTO_INCREMENT PRIMARY KEY,
      compra_id INT NOT NULL,
      tipo VARCHAR(64) NOT NULL,
      destino_id INT NOT NULL,
      cantidad_aplicada INT NOT NULL DEFAULT 0,
      actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_compra_tipo_destino (compra_id, tipo, destino_id),
      CONSTRAINT fk_compra_aplicacion FOREIGN KEY (compra_id)
        REFERENCES compras_promociones(id) ON DELETE CASCADE
    ) ENGINE=InnoDB;
  `);
}

function parseJsonField(raw) {
  if (!raw) return null;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }
  if (Buffer.isBuffer(raw)) {
    try {
      return JSON.parse(raw.toString('utf8'));
    } catch (e) {
      return null;
    }
  }
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(String(raw));
  } catch (e) {
    return null;
  }
}

async function getAppliedSlots({ compraId, tipo, destinoId }) {
  await ensureAplicacionesTable();
  const [rows] = await pool.query(
    'SELECT cantidad_aplicada FROM compras_promociones_aplicaciones WHERE compra_id = ? AND tipo = ? AND destino_id = ? LIMIT 1',
    [compraId, tipo, destinoId]
  );
  if (rows && rows[0] && Number.isFinite(rows[0].cantidad_aplicada)) {
    return Number(rows[0].cantidad_aplicada);
  }
  return 0;
}

async function setAppliedSlots({ compraId, tipo, destinoId, cantidad }) {
  await ensureAplicacionesTable();
  const [res] = await pool.query(
    'INSERT INTO compras_promociones_aplicaciones (compra_id, tipo, destino_id, cantidad_aplicada) VALUES (?, ?, ?, ?)\n      ON DUPLICATE KEY UPDATE cantidad_aplicada = VALUES(cantidad_aplicada), actualizado_en = CURRENT_TIMESTAMP',
    [compraId, tipo, destinoId, cantidad]
  );
  return res;
}

// Crear compra en DB
async function crearCompraPromocion({ titulo, monto, cantidad = 1, clinica_id, usuario_id, provider = 'mock', metadata = null }) {
  await ensureTable();
  const parsedCantidad = Number(cantidad);
  const cantidadNormalizada = Number.isFinite(parsedCantidad) && parsedCantidad > 0
    ? Math.max(1, Math.floor(parsedCantidad))
    : 1;
  const [result] = await pool.query(
    'INSERT INTO compras_promociones (titulo, monto, cantidad, clinica_id, usuario_id, provider) VALUES (?, ?, ?, ?, ?, ?)',
    [titulo, monto, cantidadNormalizada, clinica_id || null, usuario_id || null, provider]
  );
  const compraId = result.insertId;

  const metadataPayload = (metadata && typeof metadata === 'object' && !Array.isArray(metadata) && Object.keys(metadata).length > 0)
    ? metadata
    : null;

  // Persist cantidad and metadata context inside extra_data for downstream consumers
  try {
    await pool.query('ALTER TABLE compras_promociones ADD COLUMN extra_data JSON NULL');
  } catch (e) {
    // ignore if column already exists or ALTER not permitted
  }

  try {
    const toStore = metadataPayload
      ? { cantidad: cantidadNormalizada, metadata: metadataPayload }
      : { cantidad: cantidadNormalizada };
    await pool.query(
      'UPDATE compras_promociones SET extra_data = JSON_MERGE_PATCH(COALESCE(extra_data, JSON_OBJECT()), CAST(? AS JSON)) WHERE id = ?',
      [JSON.stringify(toStore), compraId]
    );
  } catch (e) {
    try {
      await pool.query("UPDATE compras_promociones SET extra_data = JSON_SET(COALESCE(extra_data, '{}'), '$.cantidad', ?) WHERE id = ?", [cantidadNormalizada, compraId]);
      if (metadataPayload) {
        await pool.query(
          "UPDATE compras_promociones SET extra_data = JSON_SET(COALESCE(extra_data, '{}'), '$.metadata_raw', ?) WHERE id = ?",
          [JSON.stringify(metadataPayload), compraId]
        );
      }
    } catch (err) {
      // ignore if JSON functions not supported
    }
  }
  // Guardar compra en Firestore para referencia rápida
  try {
    const { saveDoc } = require('./firebaseService');
    await saveDoc('compras_promociones', compraId, {
      titulo,
      monto,
      cantidad: cantidadNormalizada,
      clinica_id: clinica_id || null,
      usuario_id: usuario_id || null,
      status: 'pending',
      provider,
      metadata: metadataPayload || null,
      creado_en: new Date().toISOString(),
    });
  } catch (e) {
    console.warn('Warning: failed to save compra_promocion to Firestore', e.message || e);
  }

  // Para provider mock devolvemos una url donde el usuario puede 'pagar'
  if (provider === 'mock') {
    return {
      id: compraId,
      status: 'pending',
      payment_url: `/api/compras_promociones/mock-pay/${compraId}`
    };
  }

  // Aquí se podrían implementar otros providers
  throw new Error('Provider no soportado: ' + provider);
}

// Confirmar compra (por webhook o llamada directa)
async function confirmarCompra({ compraId, provider_txn_id }) {
  await ensureTable();
  // Marcar como completed
  const [res] = await pool.query(
    'UPDATE compras_promociones SET status = ?, provider_txn_id = ? WHERE id = ?',
    ['completed', provider_txn_id || null, compraId]
  );
  // Actualizar en Firestore también
  try {
    const { saveDoc } = require('./firebaseService');
    await saveDoc('compras_promociones', compraId, { status: 'completed', provider_txn_id: provider_txn_id || null });
  } catch (e) {
    console.warn('Warning: failed to update compra_promocion in Firestore', e.message || e);
  }

  // Aplicar efectos colaterales de la compra: si la compra corresponde a cupos de pacientes
  // para una clínica o a compras individuales para un doctor, registrar la compra en
  // las tablas correspondientes para que el conteo de slots se incremente automáticamente.
  try {
    const compra = await obtenerCompra(compraId);
    console.log('pagosService.confirmarCompra - compra fetched:', compra);
    if (compra) {
      const titulo = (compra.titulo || '').toString().toLowerCase();

      const normalizeCantidad = (value) => {
        const num = Number(value);
        if (!Number.isFinite(num) || num <= 0) return null;
        return Math.max(1, Math.floor(num));
      };

      const toInt = (value) => {
        if (value === null || value === undefined) return null;
        const num = Number(value);
        if (!Number.isFinite(num)) return null;
        return Math.trunc(num);
      };

      let extra = null;
      try {
        if (compra.extra_data) {
          extra = parseJsonField(compra.extra_data);
        }
      } catch (e) {
        console.warn('pagosService.confirmarCompra: failed to parse extra_data JSON', e.message || e);
        extra = null;
      }

      let metadata = {};
      if (extra && typeof extra === 'object' && !Array.isArray(extra)) {
        if (extra.metadata && typeof extra.metadata === 'object' && !Array.isArray(extra.metadata)) {
          metadata = { ...extra.metadata };
        }
        if (extra.metadata_raw && typeof extra.metadata_raw === 'string') {
          try {
            const parsedRaw = JSON.parse(extra.metadata_raw);
            if (parsedRaw && typeof parsedRaw === 'object' && !Array.isArray(parsedRaw)) {
              metadata = { ...parsedRaw, ...metadata };
            }
          } catch (err) {
            console.warn('pagosService.confirmarCompra: failed to parse metadata_raw JSON', err.message || err);
          }
        }
        const copyKeys = ['tipo', 'doctorId', 'doctor_id', 'usuarioId', 'usuario_id', 'clinicaId', 'clinica_id', 'clinicId', 'clinic_id', 'clinica', 'cantidadSolicitada', 'cantidad', 'quantity'];
        for (const key of copyKeys) {
          if (metadata[key] == null && extra[key] != null) {
            metadata[key] = extra[key];
          }
        }
      }

      const cantidadFromCompra = normalizeCantidad(compra.cantidad);
      const cantidadFromExtra = (extra && typeof extra === 'object')
        ? normalizeCantidad(extra.cantidad != null ? extra.cantidad : extra.cantidadSolicitada)
        : null;
      const cantidadFromMetadata = metadata
        ? normalizeCantidad(metadata.cantidadSolicitada != null ? metadata.cantidadSolicitada : (metadata.cantidad != null ? metadata.cantidad : metadata.quantity))
        : null;

      let cantidad = cantidadFromCompra || cantidadFromExtra || cantidadFromMetadata || 1;
      if (cantidadFromMetadata && cantidadFromMetadata > cantidad) cantidad = cantidadFromMetadata;
      if (cantidadFromExtra && cantidadFromExtra > cantidad) cantidad = cantidadFromExtra;
      const cantidadSlots = Math.max(1, Math.floor(cantidad));

      const metadataTipo = metadata && metadata.tipo ? metadata.tipo.toString().toLowerCase() : '';
      let doctorIdMetadata = metadata
        ? (metadata.doctorId != null ? metadata.doctorId : (metadata.doctor_id != null ? metadata.doctor_id : (metadata.usuarioId != null ? metadata.usuarioId : (metadata.usuario_id != null ? metadata.usuario_id : metadata.doctor))))
        : null;
      let clinicaIdMetadata = metadata
        ? (metadata.clinicaId != null ? metadata.clinicaId : (metadata.clinica_id != null ? metadata.clinica_id : (metadata.clinicId != null ? metadata.clinicId : (metadata.clinic_id != null ? metadata.clinic_id : metadata.clinica))))
        : null;

      const doctorIdFromMetadata = toInt(doctorIdMetadata);
      const clinicaIdFromMetadata = toInt(clinicaIdMetadata);
      const usuarioIdCompra = toInt(compra.usuario_id);
      const clinicaIdCompra = toInt(compra.clinica_id);

      const registerIndividual = async (doctorId, slotsToApply, motivo) => {
        if (!doctorId || slotsToApply <= 0) return 0;
        console.log('pagosService.confirmarCompra: registrar cupos individual', {
          compraId,
          doctor_id: doctorId,
          cantidadSolicitada: cantidadSlots,
          aplicando: slotsToApply,
          motivo,
          metadataTipo
        });
        try {
          const comprasInd = require('../modelos/comprasPacientesIndividualModelo');
          for (let i = 0; i < slotsToApply; i++) {
            await comprasInd.comprarPacienteExtraIndividual({ doctor_id: doctorId, monto: compra.monto });
          }
          return slotsToApply;
        } catch (e) {
          console.warn('Warning: failed to register compras_pacientes_individual on confirm (' + motivo + '):', e.message || e);
          return 0;
        }
      };

      const registerClinica = async (clinicaId, slotsToApply, motivo) => {
        if (!clinicaId || slotsToApply <= 0) return 0;
        console.log('pagosService.confirmarCompra: registrar cupos clínica', {
          compraId,
          clinica_id: clinicaId,
          cantidadSolicitada: cantidadSlots,
          aplicando: slotsToApply,
          motivo,
          metadataTipo
        });
        try {
          const comprasPac = require('../modelos/comprasPacientesModelo');
          for (let i = 0; i < slotsToApply; i++) {
            await comprasPac.comprarPacienteExtra({ clinica_id: clinicaId, monto: compra.monto });
          }
          return slotsToApply;
        } catch (e) {
          console.warn('Warning: failed to register compras_pacientes on confirm (' + motivo + '):', e.message || e);
          return 0;
        }
      };

      const targets = [];
      const hasIndividualTarget = () => targets.some(t => t.tipo === 'paciente_individual');
      const hasClinicaTarget = () => targets.some(t => t.tipo === 'paciente_clinica');
      const pushTarget = (tipo, destinoId, motivo) => {
        if (!destinoId) return false;
        const exists = targets.some(t => t.tipo === tipo && t.destinoId === destinoId);
        if (exists) return true;
        targets.push({ tipo, destinoId, motivo });
        return true;
      };

      if (metadataTipo === 'paciente_individual' || (!clinicaIdFromMetadata && !clinicaIdCompra && (doctorIdFromMetadata || usuarioIdCompra))) {
        const targetDoctor = doctorIdFromMetadata || usuarioIdCompra;
        if (!pushTarget('paciente_individual', targetDoctor, 'metadata')) {
          console.warn('pagosService.confirmarCompra: metadata indicaba paciente_individual pero no hay doctor destino', { compraId, metadata, usuarioIdCompra });
        }
      }

      if (metadataTipo === 'paciente_clinica' || clinicaIdFromMetadata || (clinicaIdCompra && metadataTipo !== 'paciente_individual')) {
        const targetClinica = clinicaIdFromMetadata || clinicaIdCompra;
        if (!pushTarget('paciente_clinica', targetClinica, 'metadata') && metadataTipo === 'paciente_clinica') {
          console.warn('pagosService.confirmarCompra: metadata indicaba paciente_clinica pero no se encontró clínica destino', { compraId, metadata, clinicaIdCompra });
        }
      }

      if (!hasIndividualTarget() && compra.usuario_id && !compra.clinica_id) {
        pushTarget('paciente_individual', usuarioIdCompra, 'heuristica-usuario_sin_clinica');
      }

      if (!hasClinicaTarget() && compra.clinica_id) {
        pushTarget('paciente_clinica', clinicaIdCompra, 'heuristica-clinica');
      }

      if (!targets.length) {
        if (!compra.usuario_id && !compra.clinica_id && (titulo.includes('cupo') || titulo.includes('cupos') || titulo.includes('cupo paciente'))) {
          console.warn('Confirmar compra: heurística detectó compra de cupos pero falta clinica_id/usuario_id (compraId=' + compraId + ')');
        }
      }

      const applicationSummary = {
        cantidadSolicitada: cantidadSlots,
        acciones: []
      };

      for (const target of targets) {
        if (!target.destinoId) continue;
        const tipo = target.tipo;
        let appliedBefore = 0;
        try {
          appliedBefore = await getAppliedSlots({ compraId, tipo, destinoId: target.destinoId });
        } catch (e) {
          console.warn('pagosService.confirmarCompra: no se pudo leer aplicaciones previas', { compraId, tipo, destinoId: target.destinoId, error: e.message || e });
        }
        const remaining = Math.max(0, cantidadSlots - appliedBefore);
        let appliedNow = 0;
        if (remaining > 0) {
          appliedNow = tipo === 'paciente_individual'
            ? await registerIndividual(target.destinoId, remaining, target.motivo)
            : await registerClinica(target.destinoId, remaining, target.motivo);
          if (appliedNow > 0) {
            try {
              await setAppliedSlots({ compraId, tipo, destinoId: target.destinoId, cantidad: appliedBefore + appliedNow });
            } catch (e) {
              console.warn('pagosService.confirmarCompra: no se pudo registrar resumen de aplicación', { compraId, tipo, destinoId: target.destinoId, error: e.message || e });
            }
          }
        }

        applicationSummary.acciones.push({
          tipo,
          destinoId: target.destinoId,
          motivo: target.motivo,
          aplicadoAntes: appliedBefore,
          aplicadoAhora: appliedNow,
          restante: Math.max(0, cantidadSlots - (appliedBefore + appliedNow))
        });
      }

      try {
        await pool.query(
          'UPDATE compras_promociones SET extra_data = JSON_MERGE_PATCH(COALESCE(extra_data, JSON_OBJECT()), CAST(? AS JSON)) WHERE id = ?',
          [JSON.stringify({ application_summary: applicationSummary }), compraId]
        );
      } catch (e) {
        try {
          await pool.query(
            "UPDATE compras_promociones SET extra_data = JSON_SET(COALESCE(extra_data, '{}'), '$.application_summary', CAST(? AS JSON)) WHERE id = ?",
            [JSON.stringify(applicationSummary), compraId]
          );
        } catch (fallbackErr) {
          console.warn('pagosService.confirmarCompra: no se pudo actualizar application_summary en extra_data', fallbackErr.message || fallbackErr);
        }
      }

      try {
        const { saveDoc } = require('./firebaseService');
        await saveDoc('compras_promociones', compraId, { application_summary: applicationSummary });
      } catch (e) {
        console.warn('Warning: failed to persist application_summary to Firestore', e.message || e);
      }
    }
  } catch (e) {
    console.warn('Error processing post-confirm hooks for compra_promociones:', e.message || e);
  }

  return res.affectedRows > 0;
}

async function obtenerCompra(compraId) {
  await ensureTable();
  const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE id = ? LIMIT 1', [compraId]);
  return rows[0];
}

async function listarComprasPendientes({ clinica_id = null } = {}) {
  await ensureTable();
  if (clinica_id) {
    const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE status = ? AND clinica_id = ? ORDER BY creado_en DESC', ['pending', clinica_id]);
    return rows;
  }
  const [rows] = await pool.query('SELECT * FROM compras_promociones WHERE status = ? ORDER BY creado_en DESC', ['pending']);
  return rows;
}

module.exports = {
  crearCompraPromocion,
  confirmarCompra,
  obtenerCompra
};

// Export adicional
module.exports.listarComprasPendientes = listarComprasPendientes;

