const historialModelo = require('../modelos/historialModelo');
const crypto = require('crypto');

async function listarHistorial(req, res) {
    try {
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            const registros = await historialModelo.obtenerHistorialPorDoctor(req.user.id);
            return res.json(registros);
        }
        const registros = await historialModelo.obtenerHistorialPorClinica(req.clinica_id);
        res.json(registros);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function listarHistorialPorPaciente(req, res) {
    try {
        const pacienteId = req.params.id;
        const registros = await historialModelo.obtenerHistorialPorPaciente(pacienteId);
        res.json(registros);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function verHistorial(req, res) {
    try {
        const registro = await historialModelo.obtenerHistorialPorId(req.params.id, req.clinica_id);
        if (!registro) return res.status(404).json({ message: 'Registro no encontrado' });
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            if (registro.doctor_id && registro.doctor_id !== req.user.id) {
                return res.status(403).json({ message: 'Acceso no permitido' });
            }
        }
        res.json(registro);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function crearHistorial(req, res) {
    const pool = require('../config/db');
    const pacienteIdCheck = req.body && req.body.paciente_id ? Number(req.body.paciente_id) : null;
    const fechaCheck = req.body && req.body.fecha ? req.body.fecha : null;
    const notasCheck = req.body && req.body.notas_html ? req.body.notas_html : null;

    // Instrumentación: loguear Idempotency-Key, headers y fingerprint para diagnóstico
    try {
        const idempotencyHeader = (req.headers['idempotency-key'] || req.headers['Idempotency-Key'] || '').toString();
        const nowIso = new Date().toISOString();
        const headerSnippet = Object.keys(req.headers || {}).slice(0,10).reduce((acc,k)=>{ acc[k]=req.headers[k]; return acc; },{});
        const fingerprintSource = JSON.stringify({ paciente_id: pacienteIdCheck, fecha: fechaCheck, notas_html: notasCheck });
        const fingerprint = crypto.createHash('sha256').update(fingerprintSource || '').digest('hex');
        console.log(`🔍 idempotency-log time=${nowIso} key=${idempotencyHeader} paciente=${pacienteIdCheck} fingerprint=${fingerprint}`);
        console.log('🔍 idempotency-log headers:', headerSnippet);
    } catch (e) {
        console.warn('Warning: failed to compute idempotency fingerprint', e && e.message ? e.message : e);
    }

    let lockName = null;
    let lockAcquired = false;
    try {
        if (pacienteIdCheck) {
            lockName = `historial_create_${pacienteIdCheck}`.slice(0, 60);
            const [lkRows] = await pool.query('SELECT GET_LOCK(?, 5) as lk', [lockName]);
            if (lkRows && lkRows[0] && (lkRows[0].lk === 1 || lkRows[0].lk === '1')) {
                lockAcquired = true;
            }
        }

        // NOTE: removed time-window duplicate check because production DB does not have `creado_en` column.
        // Rely on idempotency key reservation below to prevent duplicates across retries/instances.

        // Idempotency: attempt to reserve idempotency key atomically
        const idempotencyKey = (req.headers['idempotency-key'] || req.headers['Idempotency-Key'] || '').toString();
        if (idempotencyKey) {
            try {
                // Try to insert the idempotency key (resource_id NULL). If it already exists, we'll detect it.
                await pool.query('INSERT INTO idempotency_keys (idempotency_key, resource_type, resource_id) VALUES (?, ?, NULL)', [idempotencyKey, 'historial']);
                // Inserted the key successfully — proceed to create the historial record
                const payload = {
                    paciente_id: pacienteIdCheck,
                    fecha: fechaCheck,
                    notas_html: notasCheck,
                    imagenes: req.body.imagenes || []
                };
                const nuevoId = await historialModelo.crearHistorial(payload);
                console.log('🔔 crearHistorial - insertId:', nuevoId);
                try {
                    await pool.query('UPDATE idempotency_keys SET resource_id = ? WHERE idempotency_key = ?', [nuevoId, idempotencyKey]);
                } catch (e) {
                    console.warn('Warning: failed to update idempotency key after insert', e && e.message ? e.message : e);
                }
                return res.status(201).json({ id: nuevoId });
            } catch (e) {
                // Duplicate key means another process reserved or completed this operation.
                if (e && (e.code === 'ER_DUP_ENTRY' || e.errno === 1062)) {
                    // Poll a few times to see if the resource_id was set by the other process
                    const idempotencyModel = require('../modelos/idempotencyModelo');
                    for (let i = 0; i < 8; i++) {
                        try {
                            const existing = await idempotencyModel.getByKey(idempotencyKey);
                            if (existing && existing.resource_id) {
                                return res.status(200).json({ id: existing.resource_id, idempotency: true });
                            }
                        } catch (ee) {
                            // ignore and retry
                        }
                        // small sleep
                        await new Promise((r) => setTimeout(r, 200));
                    }
                    // Still no resource_id — return 409 to indicate in-progress/duplicate
                    return res.status(409).json({ message: 'Idempotency key already in use; operation in progress or failed. Intente de nuevo.' });
                }
                // Other errors: rethrow
                throw e;
            }
        }

        // No idempotency key provided — create normally
        const payload = {
            paciente_id: pacienteIdCheck,
            fecha: fechaCheck,
            notas_html: notasCheck,
            imagenes: req.body.imagenes || []
        };
        const nuevoId = await historialModelo.crearHistorial(payload);
        console.log('🔔 crearHistorial - insertId (no idempotency key):', nuevoId);
        return res.status(201).json({ id: nuevoId });
    } catch (err) {
        res.status(500).json({ message: err.message });
    } finally {
        try { if (lockAcquired) await pool.query('SELECT RELEASE_LOCK(?) as rl', [lockName]); } catch (e) {}
    }
}

async function actualizarHistorial(req, res) {
    try {
        const body = req.body || {};
        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await historialModelo.actualizarHistorial(req.params.id, body, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Registro no encontrado o sin permiso' });
        res.json({ message: 'Registro actualizado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function eliminarHistorial(req, res) {
    try {
        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await historialModelo.eliminarHistorial(req.params.id, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Registro no encontrado o sin permiso' });
        res.json({ message: 'Registro eliminado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = {
    listarHistorial,
    listarHistorialPorPaciente,
    verHistorial,
    crearHistorial,
    actualizarHistorial,
    eliminarHistorial
};
