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
    try {
        // Prevent accidental duplicate inserts from retries/clients sending twice
        // Check for a very recent identical historial (same paciente_id, fecha and notas_html)
        // within the last 10 seconds and return a 409 if found.
        // Use a db lock to avoid race between parallel requests creating the same record
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

            if (pacienteIdCheck && fechaCheck && notasCheck) {
                const [rowsDup] = await pool.query(
                    'SELECT id FROM historial WHERE paciente_id = ? AND fecha = ? AND notas_html = ? AND creado_en >= (NOW() - INTERVAL 10 SECOND) LIMIT 1',
                    [pacienteIdCheck, fechaCheck, notasCheck]
                );
                if (rowsDup && rowsDup.length > 0) {
                    // Release lock if we acquired it
                    try { if (lockAcquired) await pool.query('SELECT RELEASE_LOCK(?) as rl', [lockName]); } catch (e) {}
                    return res.status(409).json({ message: 'Registro duplicado detectado (reciente), operación ignorada', id: rowsDup[0].id });
                }
            }
        } catch (e) {
            // If lock/duplicate check fails, log and continue to normal processing
            console.warn('Warning: duplicate-check/lock failed', e && e.message ? e.message : e);
        }

        // Depuración: imprimir body y files
        console.log('🔔 crearHistorial - req.body:', req.body);
        console.log('🔔 crearHistorial - files:', (req.files || []).length);

        // Si se subieron archivos con multer, subir a Cloudinary o Firebase y construir array de URLs
        const files = req.files || [];
        const imagenes = [];
        const useFirebase = process.env.USE_FIREBASE_STORAGE === 'true';
        const { uploadFile: uploadToCloudinary } = require('../servicios/cloudinaryService');
        const { uploadFile: uploadToFirebase } = require('../servicios/firebaseService');
        for (const f of files) {
            try {
                if (pacienteIdCheck) {
                    lockName = `historial_create_${pacienteIdCheck}`.slice(0, 60);
                    const [lkRows] = await pool.query('SELECT GET_LOCK(?, 5) as lk', [lockName]);
                    if (lkRows && lkRows[0] && (lkRows[0].lk === 1 || lkRows[0].lk === '1')) {
                        lockAcquired = true;
                    }
                }

                // Check idempotency header first (if present) to return previous result
                const idempotencyKey = (req.headers['idempotency-key'] || req.headers['Idempotency-Key'] || '').toString();
                if (idempotencyKey) {
                    try {
                        const idempotencyModel = require('../modelos/idempotencyModelo');
                        const existing = await idempotencyModel.getByKey(idempotencyKey);
                        if (existing && existing.resource_id) {
                            // Return the same resource id as previously created
                            try { if (lockAcquired) await pool.query('SELECT RELEASE_LOCK(?) as rl', [lockName]); } catch (e) {}
                            return res.status(200).json({ id: existing.resource_id, idempotency: true });
                        }
                    } catch (e) {
                        console.warn('Warning: idempotency lookup failed', e && e.message ? e.message : e);
                    }
                }

                if (pacienteIdCheck && fechaCheck && notasCheck) {
                    const [rowsDup] = await pool.query(
                        'SELECT id FROM historial WHERE paciente_id = ? AND fecha = ? AND notas_html = ? AND creado_en >= (NOW() - INTERVAL 10 SECOND) LIMIT 1',
                        [pacienteIdCheck, fechaCheck, notasCheck]
                    );
                    if (rowsDup && rowsDup.length > 0) {
                        // Release lock if we acquired it
                        try { if (lockAcquired) await pool.query('SELECT RELEASE_LOCK(?) as rl', [lockName]); } catch (e) {}
                        return res.status(409).json({ message: 'Registro duplicado detectado (reciente), operación ignorada', id: rowsDup[0].id });
                    }
                }
            } catch (e) {
                // If lock/duplicate check fails, log and continue to normal processing
                console.warn('Warning: duplicate-check/lock failed', e && e.message ? e.message : e);
            }
        const files = req.files || [];
        const imagenesNuevas = [];
        const useFirebase2 = process.env.USE_FIREBASE_STORAGE === 'true';
        const { uploadFile: uploadToCloudinary2 } = require('../servicios/cloudinaryService');
        const { uploadFile: uploadToFirebase2 } = require('../servicios/firebaseService');
        for (const f of files) {
            try {
                if (useFirebase2) {
                    const dest = `clinica/historial/${Date.now()}_${f.originalname}`;
                    const r = await uploadToFirebase2(f.path, dest);
                    imagenesNuevas.push(r.publicUrl);
                try {
                    const nuevoId = await historialModelo.crearHistorial(payload);
                    console.log('🔔 crearHistorial - insertId:', nuevoId);

                    // If an idempotency key was provided, persist the mapping
                    const idempotencyKey2 = (req.headers['idempotency-key'] || req.headers['Idempotency-Key'] || '').toString();
                    if (idempotencyKey2) {
                        try {
                            const idempotencyModel = require('../modelos/idempotencyModelo');
                            await idempotencyModel.createKey(idempotencyKey2, 'historial', nuevoId);
                        } catch (e) {
                            console.warn('Warning: failed to persist idempotency key', e && e.message ? e.message : e);
                        }
                    }

                    res.status(201).json({ id: nuevoId });
                } finally {
                    try { if (lockAcquired) await pool.query('SELECT RELEASE_LOCK(?) as rl', [lockName]); } catch (e) {}
                }
            }
        }
        // Si el cliente indicó imágenes para eliminar, filtrarlas de las existentes
        if (body.imagenes_eliminar) {
            try {
                const eliminar = typeof body.imagenes_eliminar === 'string' ? JSON.parse(body.imagenes_eliminar) : body.imagenes_eliminar;
                if (Array.isArray(eliminar) && eliminar.length > 0) {
                    imagenesExistentes = imagenesExistentes.filter(i => !eliminar.includes(i));
                    // Nota: si se desea eliminar físicamente de cloudinary/firebase, hacerlo aquí.
                }
            } catch (e) {
                // ignore parse errors
            }
        }

        body.imagenes = [...imagenesExistentes, ...imagenesNuevas];

        console.log('🔔 actualizarHistorial - payload final:', body);

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
