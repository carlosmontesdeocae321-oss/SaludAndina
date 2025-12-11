const pool = require('../config/db');

// Obtener todos los registros del historial de la clínica
async function obtenerHistorialPorClinica(clinica_id) {
    const [rows] = await pool.query(
        `SELECT h.*, p.nombres, p.apellidos, p.doctor_id
         FROM historial h
         JOIN pacientes p ON h.paciente_id = p.id
         WHERE p.clinica_id = ?
         ORDER BY h.fecha DESC`,
        [clinica_id]
    );
    return rows;
}

// Obtener historial por paciente
async function obtenerHistorialPorPaciente(paciente_id) {
    const [rows] = await pool.query(
        `SELECT h.*, p.nombres, p.apellidos, p.doctor_id
         FROM historial h
         JOIN pacientes p ON h.paciente_id = p.id
         WHERE h.paciente_id = ?
         ORDER BY h.fecha DESC`,
        [paciente_id]
    );
    return rows;
}

// Obtener un registro específico
async function obtenerHistorialPorId(id, clinica_id) {
    const [rows] = await pool.query(
        `SELECT h.*, p.nombres, p.apellidos, p.doctor_id
         FROM historial h
         JOIN pacientes p ON h.paciente_id = p.id
         WHERE h.id = ? LIMIT 1`,
        [id]
    );
    return rows[0];
}

// Crear registro de historial
async function crearHistorial(historial) {
    const {
        client_local_id,
        paciente_id,
        motivo_consulta,
        notas_html,
        notas_html_full,
        peso,
        estatura,
        imc,
        presion,
        frecuencia_cardiaca,
        frecuencia_respiratoria,
        temperatura,
        otros,
        diagnostico,
        tratamiento,
        receta,
        fecha,
        imagenes
    } = historial;

    // Persist client_local_id when provided to allow client deduplication
    const [result] = await pool.query(
        `INSERT INTO historial 
         (client_local_id, paciente_id, motivo_consulta, notas_html, notas_html_full, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, imagenes) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            client_local_id ?? null,
            paciente_id,
            motivo_consulta ?? null,
            notas_html ?? null,
            notas_html_full ?? null,
            peso ?? null,
            estatura ?? null,
            imc ?? null,
            presion ?? null,
            frecuencia_cardiaca ?? null,
            frecuencia_respiratoria ?? null,
            temperatura ?? null,
            otros ?? null,
            diagnostico ?? null,
            tratamiento ?? null,
            receta ?? null,
            fecha ?? null,
            JSON.stringify((imagenes || []).filter((v) => v != null))
        ]
    );

    const id = result.insertId;
    try {
        const { saveDoc } = require('../servicios/firebaseService');
        await saveDoc('medical_history', id, sanitizeDoc({
            id,
            client_local_id: client_local_id ?? null,
            pacienteId: paciente_id ?? null,
            motivo_consulta: motivo_consulta ?? null,
            notas_html: notas_html ?? null,
            notas_html_full: notas_html_full ?? null,
            peso: peso ?? null,
            estatura: estatura ?? null,
            imc: imc ?? null,
            presion: presion ?? null,
            frecuencia_cardiaca: frecuencia_cardiaca ?? null,
            frecuencia_respiratoria: frecuencia_respiratoria ?? null,
            temperatura: temperatura ?? null,
            otros: otros ?? null,
            diagnostico: diagnostico ?? null,
            tratamiento: tratamiento ?? null,
            receta: receta ?? null,
            fecha: fecha ? new Date(fecha).toISOString() : null,
            imagenes: (imagenes || []).filter((v) => v != null)
        }));
    } catch (e) {
        console.warn('Warning: failed to save historial to Firestore', e.message || e);
    }
    return id;
}

// Buscar historial por client_local_id (fallback to Firestore if SQL misses)
async function obtenerHistorialPorClientLocalId(clientLocalId) {
    if (!clientLocalId) return null;
    try {
        const [rows] = await pool.query(
            `SELECT h.*, p.nombres, p.apellidos, p.doctor_id
             FROM historial h
             JOIN pacientes p ON h.paciente_id = p.id
             WHERE h.client_local_id = ? LIMIT 1`,
            [clientLocalId]
        );
        if (rows && rows.length) return rows[0];
    } catch (e) {
        // ignore and fallback to firestore
    }
    try {
        const { findInCollectionByField } = require('../servicios/firebaseService');
        const doc = await findInCollectionByField('medical_history', 'client_local_id', clientLocalId);
        if (doc) return doc;
    } catch (e) {
        // ignore
    }
    return null;
}

// Actualizar registro de historial
async function actualizarHistorial(id, historial, clinica_id, doctor_id) {
    const {
        paciente_id,
        motivo_consulta,
        notas_html,
        notas_html_full,
        peso,
        estatura,
        imc,
        presion,
        frecuencia_cardiaca,
        frecuencia_respiratoria,
        temperatura,
        otros,
        diagnostico,
        tratamiento,
        receta,
        fecha,
        imagenes
    } = historial;

    if (clinica_id) {
        const [result] = await pool.query(
            `UPDATE historial h
             JOIN pacientes p ON h.paciente_id = p.id
             SET h.paciente_id=?, h.motivo_consulta=?, h.notas_html=?, h.peso=?, h.estatura=?, h.imc=?, h.presion=?, h.frecuencia_cardiaca=?, h.frecuencia_respiratoria=?, h.temperatura=?, h.otros=?, h.diagnostico=?, h.tratamiento=?, h.receta=?, h.fecha=?, h.imagenes=?
             WHERE h.id=? AND p.clinica_id=?`,
            [
                paciente_id,
                motivo_consulta ?? null,
                notas_html ?? null,
                notas_html_full ?? null,
                peso ?? null,
                estatura ?? null,
                imc ?? null,
                presion ?? null,
                frecuencia_cardiaca ?? null,
                frecuencia_respiratoria ?? null,
                temperatura ?? null,
                otros ?? null,
                diagnostico ?? null,
                tratamiento ?? null,
                receta ?? null,
                fecha ?? null,
                JSON.stringify((imagenes || []).filter((v) => v != null)),
                id,
                clinica_id
            ]
        );
        try {
            const { saveDoc } = require('../servicios/firebaseService');
            await saveDoc('medical_history', id, sanitizeDoc({
                pacienteId: paciente_id ?? null,
                motivo_consulta: motivo_consulta ?? null,
                notas_html: notas_html ?? null,
                notas_html_full: notas_html_full ?? null,
                peso: peso ?? null,
                estatura: estatura ?? null,
                imc: imc ?? null,
                presion: presion ?? null,
                frecuencia_cardiaca: frecuencia_cardiaca ?? null,
                frecuencia_respiratoria: frecuencia_respiratoria ?? null,
                temperatura: temperatura ?? null,
                otros: otros ?? null,
                diagnostico: diagnostico ?? null,
                tratamiento: tratamiento ?? null,
                receta: receta ?? null,
                fecha: fecha ? new Date(fecha).toISOString() : null,
                imagenes: (imagenes || []).filter((v) => v != null)
            }));
        } catch (e) {
            console.warn('Warning: failed to update historial in Firestore', e.message || e);
        }
        return result.affectedRows;
    } else if (doctor_id) {
        const [result] = await pool.query(
            `UPDATE historial h
             JOIN pacientes p ON h.paciente_id = p.id
             SET h.paciente_id=?, h.motivo_consulta=?, h.notas_html=?, h.peso=?, h.estatura=?, h.imc=?, h.presion=?, h.frecuencia_cardiaca=?, h.frecuencia_respiratoria=?, h.temperatura=?, h.otros=?, h.diagnostico=?, h.tratamiento=?, h.receta=?, h.fecha=?, h.imagenes=?
             WHERE h.id=? AND p.doctor_id=?`,
            [
                paciente_id,
                motivo_consulta ?? null,
                notas_html ?? null,
                peso ?? null,
                estatura ?? null,
                imc ?? null,
                presion ?? null,
                frecuencia_cardiaca ?? null,
                frecuencia_respiratoria ?? null,
                temperatura ?? null,
                otros ?? null,
                diagnostico ?? null,
                tratamiento ?? null,
                receta ?? null,
                fecha ?? null,
                JSON.stringify((imagenes || []).filter((v) => v != null)),
                id,
                doctor_id
            ]
        );
        try {
            const { saveDoc } = require('../servicios/firebaseService');
            await saveDoc('medical_history', id, sanitizeDoc({
                pacienteId: paciente_id ?? null,
                motivo_consulta: motivo_consulta ?? null,
                notas_html: notas_html ?? null,
                peso: peso ?? null,
                estatura: estatura ?? null,
                imc: imc ?? null,
                presion: presion ?? null,
                frecuencia_cardiaca: frecuencia_cardiaca ?? null,
                frecuencia_respiratoria: frecuencia_respiratoria ?? null,
                temperatura: temperatura ?? null,
                otros: otros ?? null,
                diagnostico: diagnostico ?? null,
                tratamiento: tratamiento ?? null,
                receta: receta ?? null,
                fecha: fecha ? new Date(fecha).toISOString() : null,
                imagenes: (imagenes || []).filter((v) => v != null)
            }));
        } catch (e) {
            console.warn('Warning: failed to update historial in Firestore', e.message || e);
        }
        return result.affectedRows;
    } else {
        return 0;
    }
}

// Eliminar historial
async function eliminarHistorial(id, clinica_id, doctor_id) {
    if (clinica_id) {
        const [result] = await pool.query(
            `DELETE h FROM historial h
             JOIN pacientes p ON h.paciente_id = p.id
             WHERE h.id=? AND p.clinica_id=?`,
            [id, clinica_id]
        );
        try {
            const { deleteDoc } = require('../servicios/firebaseService');
            await deleteDoc('medical_history', id);
        } catch (e) {
            console.warn('Warning: failed to delete historial from Firestore', e.message || e);
        }
        return result.affectedRows;
    } else if (doctor_id) {
        const [result] = await pool.query(
            `DELETE h FROM historial h
             JOIN pacientes p ON h.paciente_id = p.id
             WHERE h.id=? AND p.doctor_id=?`,
            [id, doctor_id]
        );
        try {
            const { deleteDoc } = require('../servicios/firebaseService');
            await deleteDoc('medical_history', id);
        } catch (e) {
            console.warn('Warning: failed to delete historial from Firestore', e.message || e);
        }
        return result.affectedRows;
    } else {
        return 0;
    }
}

// Obtener historial para pacientes de un doctor
async function obtenerHistorialPorDoctor(doctor_id) {
    const [rows] = await pool.query(
        `SELECT h.*, p.nombres, p.apellidos, p.doctor_id
         FROM historial h
         JOIN pacientes p ON h.paciente_id = p.id
         WHERE p.doctor_id = ?
         ORDER BY h.fecha DESC`,
        [doctor_id]
    );
    return rows;
}

function sanitizeDoc(obj) {
    if (!obj || typeof obj !== 'object') return obj;
    const result = {};
    for (const [key, value] of Object.entries(obj)) {
        if (value === undefined) continue;
        if (Array.isArray(value)) {
            result[key] = value.map((item) => (item === undefined ? null : item));
        } else {
            result[key] = value;
        }
    }
    return result;
}

module.exports = {
    obtenerHistorialPorClinica,
    obtenerHistorialPorPaciente,
    obtenerHistorialPorId,
    crearHistorial,
    actualizarHistorial,
    eliminarHistorial
};
