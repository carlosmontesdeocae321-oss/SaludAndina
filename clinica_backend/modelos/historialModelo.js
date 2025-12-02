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
    const { paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, imagenes } = historial;

    const [result] = await pool.query(
        `INSERT INTO historial 
         (paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, imagenes) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, JSON.stringify(imagenes || [])]
    );

    const id = result.insertId;
    try {
        const { saveDoc } = require('../servicios/firebaseService');
        await saveDoc('medical_history', id, { pacienteId: paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha: fecha ? new Date(fecha).toISOString() : null, imagenes: imagenes || [] });
    } catch (e) {
        console.warn('Warning: failed to save historial to Firestore', e.message || e);
    }
    return id;
}

// Actualizar registro de historial
async function actualizarHistorial(id, historial, clinica_id, doctor_id) {
    const { paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, imagenes } = historial;

    if (clinica_id) {
        const [result] = await pool.query(
            `UPDATE historial h
             JOIN pacientes p ON h.paciente_id = p.id
             SET h.paciente_id=?, h.motivo_consulta=?, h.peso=?, h.estatura=?, h.imc=?, h.presion=?, h.frecuencia_cardiaca=?, h.frecuencia_respiratoria=?, h.temperatura=?, h.otros=?, h.diagnostico=?, h.tratamiento=?, h.receta=?, h.fecha=?, h.imagenes=?
             WHERE h.id=? AND p.clinica_id=?`,
            [paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, JSON.stringify(imagenes || []), id, clinica_id]
        );
        try {
            const { saveDoc } = require('../servicios/firebaseService');
            await saveDoc('medical_history', id, { pacienteId: paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha: fecha ? new Date(fecha).toISOString() : null, imagenes: imagenes || [] });
        } catch (e) {
            console.warn('Warning: failed to update historial in Firestore', e.message || e);
        }
        return result.affectedRows;
    } else if (doctor_id) {
        const [result] = await pool.query(
            `UPDATE historial h
             JOIN pacientes p ON h.paciente_id = p.id
             SET h.paciente_id=?, h.motivo_consulta=?, h.peso=?, h.estatura=?, h.imc=?, h.presion=?, h.frecuencia_cardiaca=?, h.frecuencia_respiratoria=?, h.temperatura=?, h.otros=?, h.diagnostico=?, h.tratamiento=?, h.receta=?, h.fecha=?, h.imagenes=?
             WHERE h.id=? AND p.doctor_id=?`,
            [paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha, JSON.stringify(imagenes || []), id, doctor_id]
        );
        try {
            const { saveDoc } = require('../servicios/firebaseService');
            await saveDoc('medical_history', id, { pacienteId: paciente_id, motivo_consulta, peso, estatura, imc, presion, frecuencia_cardiaca, frecuencia_respiratoria, temperatura, otros, diagnostico, tratamiento, receta, fecha: fecha ? new Date(fecha).toISOString() : null, imagenes: imagenes || [] });
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

module.exports = {
    obtenerHistorialPorClinica,
    obtenerHistorialPorPaciente,
    obtenerHistorialPorId,
    crearHistorial,
    actualizarHistorial,
    eliminarHistorial
};
