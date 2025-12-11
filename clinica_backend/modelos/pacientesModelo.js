// Obtener pacientes por doctor individual
async function obtenerPacientesPorDoctor(doctor_id) {
    const [rows] = await pool.query(
        'SELECT * FROM pacientes WHERE doctor_id = ? ORDER BY id DESC',
        [doctor_id]
    );
    return rows;
}
const pool = require('../config/db');

async function obtenerPacientesPorClinica(clinica_id) {
    // Devolver pacientes que pertenecen a la clínica directamente (clinica_id)
    // y también pacientes cuyos doctor_id correspondan a doctores que actualmente
    // pertenecen a la misma clínica (usuarios.clinica_id = ?).
    // Esto asegura que pacientes de doctores vinculados se muestren en la vista
    // de la clínica incluso si por alguna razón no fueron migrados.
    const sql = `
        SELECT p.* FROM pacientes p
        WHERE p.clinica_id = ?
        OR p.doctor_id IN (SELECT id FROM usuarios WHERE clinica_id = ?)
        ORDER BY p.id DESC
    `;
    const [rows] = await pool.query(sql, [clinica_id, clinica_id]);
    return rows;
}

async function obtenerPacientePorId(id, clinica_id) {
    if (clinica_id) {
        const [rows] = await pool.query(
            'SELECT * FROM pacientes WHERE id = ? AND clinica_id = ?',
            [id, clinica_id]
        );
        return rows[0];
    } else {
        const [rows] = await pool.query(
            'SELECT * FROM pacientes WHERE id = ? LIMIT 1',
            [id]
        );
        return rows[0];
    }
}

async function obtenerPacientePorCedula(cedula) {
    const [rows] = await pool.query(
        'SELECT * FROM pacientes WHERE cedula = ?',
        [cedula]
    );
    return rows[0];
}

async function obtenerPacientePorCedulaGlobal(cedula) {
    const [rows] = await pool.query(
        'SELECT * FROM pacientes WHERE cedula = ? LIMIT 1',
        [cedula]
    );
    return rows[0];
}

const { saveDoc, deleteDoc } = require('../servicios/firebaseService');
const fs = require('fs');
const path = require('path');

function _appendLog(line) {
    try {
        const logsDir = path.join(__dirname, '..', 'logs');
        if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });
        const file = path.join(logsDir, 'client_local_id.log');
        fs.appendFileSync(file, line + '\n');
    } catch (e) {
        console.warn('Failed to write client_local_id log:', e && e.message ? e.message : e);
    }
}

async function crearPaciente(paciente) {
    const { nombres, apellidos, cedula, telefono, direccion, fecha_nacimiento, clinica_id, doctor_id } = paciente;
    // Si doctor individual intenta crear paciente, aplicar límite dinámico (base 20 + extras comprados, tope 80)
    // Aplicar límite base para doctor individual: base 20 + extras comprados (sin tope)
    if ((!clinica_id || clinica_id === null) && doctor_id) {
        const comprasInd = require('./comprasPacientesIndividualModelo');
        // Contar pacientes del doctor
        const [rows] = await pool.query('SELECT COUNT(*) AS c FROM pacientes WHERE doctor_id = ?', [doctor_id]);
        const count = rows[0] ? rows[0].c : 0;
        const extraComprados = await comprasInd.obtenerPacientesCompradosIndividual(doctor_id) || 0;
        const base = 20;
        const limiteCalculado = base + extraComprados; // no cap
        if (count >= limiteCalculado) {
            const err = new Error('Límite de pacientes para doctor individual alcanzado. Compra más pacientes.');
            err.code = 'LIMIT_DOCTOR_PACIENTES';
            throw err;
        }
    }
    const columns = ['nombres','apellidos','cedula','telefono','direccion','fecha_nacimiento'];
    const placeholders = ['?','?','?','?','?','?'];
    const values = [nombres, apellidos, cedula, telefono, direccion, fecha_nacimiento];

    // Support storing client_local_id in SQL for robust lookup
    const clientLocalId = paciente && (paciente.client_local_id || paciente.clientLocalId) ? (paciente.client_local_id || paciente.clientLocalId) : null;
    if (clientLocalId) {
        columns.push('client_local_id');
        placeholders.push('?');
        values.push(clientLocalId);
    }

    if (typeof clinica_id !== 'undefined' && clinica_id !== null) {
        columns.push('clinica_id');
        placeholders.push('?');
        values.push(clinica_id);
    }
    if (typeof doctor_id !== 'undefined' && doctor_id !== null) {
        columns.push('doctor_id');
        placeholders.push('?');
        values.push(doctor_id);
    }

    const sql = `INSERT INTO pacientes (${columns.join(',')}) VALUES (${placeholders.join(',')})`;
        const [result] = await pool.query(sql, values);
        const id = result.insertId;
        // Telemetry: log mapping between client_local_id and created server id
        try {
            const logLine = JSON.stringify({ ts: new Date().toISOString(), id: id, client_local_id: clientLocalId || null });
            _appendLog(logLine);
        } catch (_) {}
        try {
            const payload = {
                nombres: nombres,
                apellidos: apellidos,
                cedula: cedula,
                telefono: telefono,
                direccion: direccion,
                doctorId: doctor_id || null,
                clinicaId: clinica_id || null,
                creado_en: null
            };
            // If client provided a client_local_id, include it in Firestore payload
            if (paciente && (paciente.client_local_id || paciente.clientLocalId)) {
                payload.client_local_id = paciente.client_local_id || paciente.clientLocalId;
            }
            await saveDoc('patients', id, payload);
        } catch (e) {
            console.warn('Warning: failed to save paciente to Firestore', e.message || e);
        }
        return id;
}

// Try to locate a paciente by a client-local id stored in Firestore (best-effort).
async function obtenerPacientePorClientLocalId(clientLocalId) {
    try {
        // First try to find in SQL for better performance and reliability
        try {
            const [rows] = await pool.query('SELECT * FROM pacientes WHERE client_local_id = ? LIMIT 1', [clientLocalId]);
            if (rows && rows.length > 0) {
                const r = rows[0];
                return {
                    id: r.id,
                    nombres: r.nombres,
                    apellidos: r.apellidos,
                    cedula: r.cedula,
                    telefono: r.telefono,
                    direccion: r.direccion,
                    doctorId: r.doctor_id || null,
                    clinicaId: r.clinica_id || null,
                    client_local_id: r.client_local_id || null
                };
            }
        } catch (sqlErr) {
            console.warn('SQL lookup by client_local_id failed, falling back to Firestore:', sqlErr.message || sqlErr);
        }

        // Fallback to Firestore when SQL doesn't contain the mapping
        const { findInCollectionByField } = require('../servicios/firebaseService');
        const doc = await findInCollectionByField('patients', 'client_local_id', clientLocalId);
        if (!doc) return null;
        // Map Firestore doc fields to server-side patient schema expected by client
        return {
            id: doc.id,
            nombres: doc.nombres,
            apellidos: doc.apellidos,
            cedula: doc.cedula,
            telefono: doc.telefono,
            direccion: doc.direccion,
            doctorId: doc.doctorId || null,
            clinicaId: doc.clinicaId || null,
            client_local_id: doc.client_local_id || null
        };
    } catch (e) {
        console.warn('obtenerPacientePorClientLocalId error:', e.message || e);
        return null;
    }
}

async function actualizarPaciente(id, paciente, clinica_id, doctor_id) {
    const { nombres, apellidos, cedula, telefono, direccion, fecha_nacimiento } = paciente;
    const fields = ['nombres=?','apellidos=?','cedula=?','telefono=?','direccion=?','fecha_nacimiento=?'];
    const values = [nombres, apellidos, cedula, telefono, direccion, fecha_nacimiento];

    let sql = `UPDATE pacientes SET ${fields.join(',')} WHERE id=?`;
    values.push(id);

    if (clinica_id) {
        sql += ' AND clinica_id=?';
        values.push(clinica_id);
    } else if (doctor_id) {
        sql += ' AND doctor_id=?';
        values.push(doctor_id);
    } else {
        // No se puede determinar propietario
        return 0;
    }

        const [result] = await pool.query(sql, values);
        try {
            const payload = { nombres, apellidos, cedula, telefono, direccion, fecha_nacimiento };
            await saveDoc('patients', id, payload);
        } catch (e) {
            console.warn('Warning: failed to update paciente in Firestore', e.message || e);
        }
        return result.affectedRows;
}

async function eliminarPaciente(id, clinica_id, doctor_id) {
    // Eliminar paciente de forma segura: primero eliminar dependencias (historial, citas)
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();

        // Verificar que el paciente pertenece a la clínica o al doctor (según corresponda)
        let whereSql = ' WHERE id = ?';
        const whereVals = [id];
        if (clinica_id) {
            whereSql += ' AND clinica_id = ?';
            whereVals.push(clinica_id);
        } else if (doctor_id) {
            whereSql += ' AND doctor_id = ?';
            whereVals.push(doctor_id);
        } else {
            await conn.rollback();
            conn.release();
            return 0;
        }

        const [checkRows] = await conn.query('SELECT id FROM pacientes' + whereSql, whereVals);
        console.log('===> eliminarPaciente - checkRows:', checkRows);
        if (!checkRows || checkRows.length === 0) {
            console.log('===> eliminarPaciente - paciente no encontrado o sin permiso');
            await conn.rollback();
            conn.release();
            return 0;
        }

        // Borrar historial asociado
        console.log('===> eliminarPaciente - borrando historial for paciente_id=', id);
        const [histDel] = await conn.query('DELETE FROM historial WHERE paciente_id = ?', [id]);
        console.log('===> eliminarPaciente - historial eliminado filas:', histDel.affectedRows);
        // Borrar citas asociadas
        console.log('===> eliminarPaciente - borrando citas for paciente_id=', id);
        const [citasDel] = await conn.query('DELETE FROM citas WHERE paciente_id = ?', [id]);
        console.log('===> eliminarPaciente - citas eliminadas filas:', citasDel.affectedRows);
        // Finalmente borrar paciente
                const [delResult] = await conn.query('DELETE FROM pacientes' + whereSql, whereVals);
        console.log('===> eliminarPaciente - paciente eliminado filas:', delResult.affectedRows);

        await conn.commit();
        conn.release();
                try {
                    await deleteDoc('patients', id);
                } catch (e) {
                    console.warn('Warning: failed to delete paciente from Firestore', e.message || e);
                }
                return delResult.affectedRows;
    } catch (err) {
        try { await conn.rollback(); } catch (e) {}
        conn.release();
        throw err;
    }
}

module.exports = {
    obtenerPacientesPorClinica,
    obtenerPacientePorId,
    crearPaciente,
    actualizarPaciente,
    eliminarPaciente,
    obtenerPacientePorCedula,
    obtenerPacientePorCedulaGlobal,
    obtenerPacientesPorDoctor
    , obtenerPacientePorClientLocalId
};
