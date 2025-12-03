const pool = require('../config/db');
const { saveDoc, deleteDoc } = require('../servicios/firebaseService');

// Obtener todas las citas de la clínica
async function obtenerCitasPorClinica(clinica_id) {
    const [rows] = await pool.query(
        'SELECT c.*, p.nombres, p.apellidos, p.doctor_id FROM citas c JOIN pacientes p ON c.paciente_id = p.id WHERE c.clinica_id = ? ORDER BY c.fecha, c.hora',
        [clinica_id]
    );
    return rows;
}

// Obtener citas por doctor individual (pacientes cuyo doctor_id = ?)
async function obtenerCitasPorDoctor(doctor_id) {
    const [rows] = await pool.query(
        'SELECT c.*, p.nombres, p.apellidos, p.doctor_id FROM citas c JOIN pacientes p ON c.paciente_id = p.id WHERE p.doctor_id = ? ORDER BY c.fecha, c.hora',
        [doctor_id]
    );
    return rows;
}

// Obtener citas por paciente (para vistas públicas o detalle de paciente)
async function obtenerCitasPorPaciente(paciente_id) {
    const [rows] = await pool.query(
        'SELECT c.*, p.nombres, p.apellidos, p.doctor_id FROM citas c JOIN pacientes p ON c.paciente_id = p.id WHERE c.paciente_id = ? ORDER BY c.fecha, c.hora',
        [paciente_id]
    );
    return rows;
}

// Obtener una cita por id y clínica
async function obtenerCitaPorId(id, clinica_id) {
    if (clinica_id) {
        const [rows] = await pool.query(
            'SELECT c.*, p.nombres, p.apellidos, p.doctor_id FROM citas c JOIN pacientes p ON c.paciente_id = p.id WHERE c.id = ? AND c.clinica_id = ?',
            [id, clinica_id]
        );
        return rows[0];
    } else {
        const [rows] = await pool.query(
            'SELECT c.*, p.nombres, p.apellidos, p.doctor_id FROM citas c JOIN pacientes p ON c.paciente_id = p.id WHERE c.id = ? LIMIT 1',
            [id]
        );
        return rows[0];
    }
}

// Crear cita
async function crearCita(cita) {
    const { paciente_id, fecha, hora, motivo, estado, clinica_id } = cita;
    if (typeof clinica_id !== 'undefined' && clinica_id !== null) {
        const [result] = await pool.query(
            'INSERT INTO citas (paciente_id, fecha, hora, motivo, estado, clinica_id) VALUES (?, ?, ?, ?, ?, ?)',
            [paciente_id, fecha, hora, motivo, estado || 'programada', clinica_id]
        );
        const id = result.insertId;
        try {
          await saveDoc('appointments', id, { pacienteId: paciente_id, fecha, hora, motivo, estado: estado || 'programada', clinicaId: clinica_id || null });
        } catch (e) {
          console.warn('Warning: failed to save cita to Firestore', e.message || e);
        }
        return id;
    } else {
        // Doctor individual: no insertar clinica_id (si la columna no acepta NULL en la DB)
        const [result] = await pool.query(
            'INSERT INTO citas (paciente_id, fecha, hora, motivo, estado) VALUES (?, ?, ?, ?, ?)',
            [paciente_id, fecha, hora, motivo, estado || 'programada']
        );
        const id = result.insertId;
        try {
          await saveDoc('appointments', id, { pacienteId: paciente_id, fecha, hora, motivo, estado: estado || 'programada', clinicaId: null });
        } catch (e) {
          console.warn('Warning: failed to save cita to Firestore', e.message || e);
        }
        return id;
    }
}

// Actualizar cita
async function actualizarCita(id, cita, clinica_id, doctor_id) {
    const { paciente_id, fecha, hora, motivo, estado } = cita;
    if (clinica_id) {
        const [result] = await pool.query(
            'UPDATE citas SET paciente_id=?, fecha=?, hora=?, motivo=?, estado=? WHERE id=? AND clinica_id=?',
            [paciente_id, fecha, hora, motivo, estado, id, clinica_id]
        );
        try {
          await saveDoc('appointments', id, { pacienteId: paciente_id, fecha, hora, motivo, estado, clinicaId: clinica_id || null });
        } catch (e) {
          console.warn('Warning: failed to update cita in Firestore', e.message || e);
        }
        return result.affectedRows;
    } else if (doctor_id) {
        // Asegurar que el paciente pertenece al doctor
        const [result] = await pool.query(
            'UPDATE citas c JOIN pacientes p ON c.paciente_id = p.id SET c.paciente_id=?, c.fecha=?, c.hora=?, c.motivo=?, c.estado=? WHERE c.id=? AND p.doctor_id=?',
            [paciente_id, fecha, hora, motivo, estado, id, doctor_id]
        );
        try {
          await saveDoc('appointments', id, { pacienteId: paciente_id, fecha, hora, motivo, estado });
        } catch (e) {
          console.warn('Warning: failed to update cita in Firestore', e.message || e);
        }
        return result.affectedRows;
    } else {
        return 0;
    }
}

// Eliminar cita
async function eliminarCita(id, clinica_id, doctor_id) {
    if (clinica_id) {
        const [result] = await pool.query(
            'DELETE FROM citas WHERE id=? AND clinica_id=?',
            [id, clinica_id]
        );
        try {
          await deleteDoc('appointments', id);
        } catch (e) {
          console.warn('Warning: failed to delete cita from Firestore', e.message || e);
        }
        return result.affectedRows;
    } else if (doctor_id) {
        const [result] = await pool.query(
            'DELETE c FROM citas c JOIN pacientes p ON c.paciente_id = p.id WHERE c.id=? AND p.doctor_id=?',
            [id, doctor_id]
        );
        try {
          await deleteDoc('appointments', id);
        } catch (e) {
          console.warn('Warning: failed to delete cita from Firestore', e.message || e);
        }
        return result.affectedRows;
    } else {
        return 0;
    }
}

module.exports = {
    obtenerCitasPorClinica,
    obtenerCitasPorDoctor,
    obtenerCitasPorPaciente,
    obtenerCitaPorId,
    crearCita,
    actualizarCita,
    eliminarCita
};
