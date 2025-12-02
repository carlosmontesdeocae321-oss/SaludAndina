const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const SALT_ROUNDS = 10;

// Vincular doctor individual como dueño de clínica
async function vincularDoctorComoDueno(doctorId, clinicaId) {
    const [result] = await pool.query(
        'UPDATE usuarios SET clinica_id=?, dueno=1 WHERE id=?',
        [clinicaId, doctorId]
    );
    return result.affectedRows;
}

// Obtener todos los usuarios de la clínica
async function obtenerUsuariosPorClinica(clinica_id) {
    const [rows] = await pool.query(
        'SELECT id, usuario, rol, creado_en, clinica_id FROM usuarios WHERE clinica_id = ? ORDER BY usuario',
        [clinica_id]
    );
    return rows;
}

// Obtener un usuario por id y clínica
async function obtenerUsuarioPorId(id, clinica_id) {
    const [rows] = await pool.query(
        'SELECT id, usuario, rol, creado_en, clinica_id FROM usuarios WHERE id = ? AND clinica_id = ?',
        [id, clinica_id]
    );
    return rows[0];
}

// Crear usuario
const { saveDoc, deleteDoc } = require('../servicios/firebaseService');

async function crearUsuario(usuario) {
    const { usuario: nombre, clave, rol, clinica_id, dueno } = usuario;
    // Hash the password before storing
    const hashed = await bcrypt.hash(clave, SALT_ROUNDS);
        if (rol === 'doctor' && !clinica_id) {
        // Doctor individual sin clínica
        const [result] = await pool.query(
            'INSERT INTO usuarios (usuario, clave, rol, dueno) VALUES (?, ?, ?, ?)',
            [nombre, hashed, rol, dueno ? 1 : 0]
        );
                const id = result.insertId;
                try {
                    await saveDoc('users', id, { usuario: nombre, rol, clinicaId: null, dueno: !!dueno });
                } catch (e) {
                    console.warn('Warning: failed to save usuario to Firestore', e.message || e);
                }
                return id;
    } else {
        // Usuario de clínica (requiere clinica_id)
        // Forzar que los usuarios creados por una clínica no sean dueños
        const duenoValue = 0;
        const [result] = await pool.query(
            'INSERT INTO usuarios (usuario, clave, rol, clinica_id, dueno) VALUES (?, ?, ?, ?, ?)',
            [nombre, hashed, rol, clinica_id, duenoValue]
        );
                const id = result.insertId;
                try {
                    await saveDoc('users', id, { usuario: nombre, rol, clinicaId: clinica_id || null, dueno: false });
                } catch (e) {
                    console.warn('Warning: failed to save usuario to Firestore', e.message || e);
                }
                return id;
    }
}

async function generarUsuarioDisponible(base) {
    let candidato = base;
    let intento = 0;
    while (true) {
        const [rows] = await pool.query('SELECT id FROM usuarios WHERE usuario = ? LIMIT 1', [candidato]);
        if (!rows || rows.length === 0) {
            return candidato;
        }
        intento += 1;
        if (intento > 25) {
            candidato = `${base}${Date.now()}`;
        } else {
            candidato = `${base}${intento}`;
        }
    }
}

async function obtenerUsuarioPorFirebaseUid(firebaseUid) {
    if (!firebaseUid) return null;
    const [rows] = await pool.query(
        'SELECT id, usuario, rol, clinica_id, dueno, google_email FROM usuarios WHERE firebase_uid = ? LIMIT 1',
        [firebaseUid]
    );
    if (!rows || rows.length === 0) return null;
    const row = rows[0];
    return {
        id: row.id,
        usuario: row.usuario,
        rol: row.rol,
        clinica_id: row.clinica_id,
        dueno: row.dueno,
        google_email: row.google_email || null
    };
}

async function actualizarEmailGoogle(id, email) {
    if (!id) return;
    await pool.query('UPDATE usuarios SET google_email = ? WHERE id = ?', [email || null, id]);
}

async function crearUsuarioDesdeGoogle({ firebaseUid, email, displayName }) {
    if (!firebaseUid) {
        throw new Error('firebaseUid requerido');
    }

    const baseRaw = (email && email.split('@')[0]) || (displayName || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    let base = baseRaw && baseRaw.length >= 3 ? baseRaw : `doctor${firebaseUid.substring(0, 6)}`;
    base = base.toLowerCase().replace(/[^a-z0-9_]/g, '');
    if (base.length < 3) {
        base = `doctor${Date.now()}`;
    }

    const usuarioDisponible = await generarUsuarioDisponible(base);

    const randomSecret = crypto.randomBytes(24).toString('hex');
    const hashed = await bcrypt.hash(randomSecret, SALT_ROUNDS);

    const [result] = await pool.query(
        'INSERT INTO usuarios (usuario, clave, rol, dueno, firebase_uid, google_email) VALUES (?, ?, ?, ?, ?, ?)',
        [usuarioDisponible, hashed, 'doctor', 0, firebaseUid, email || null]
    );

    const id = result.insertId;
    try {
        await saveDoc('users', id, { usuario: usuarioDisponible, rol: 'doctor', clinicaId: null, dueno: false, firebaseUid });
    } catch (e) {
        console.warn('Warning: failed to save usuario (google) to Firestore', e.message || e);
    }

    return {
        id,
        usuario: usuarioDisponible,
        rol: 'doctor',
        clinica_id: null,
        dueno: 0,
        google_email: email || null
    };
}

// Crear usuario admin/dueno para una clínica (dueno = 1)
async function crearUsuarioClinicaAdmin({ usuario: nombre, clave, rol = 'clinica', clinica_id }) {
    const hashed = await bcrypt.hash(clave, SALT_ROUNDS);
    const duenoValue = 1;
    console.log('crearUsuarioClinicaAdmin - creating user for clinica', clinica_id, 'usuario:', nombre);
    const [result] = await pool.query(
        'INSERT INTO usuarios (usuario, clave, rol, clinica_id, dueno) VALUES (?, ?, ?, ?, ?)',
        [nombre, hashed, rol, clinica_id, duenoValue]
    );
    const id = result.insertId;
    console.log('crearUsuarioClinicaAdmin - inserted usuario id:', id);
    try {
        await saveDoc('users', id, { usuario: nombre, rol, clinicaId: clinica_id || null, dueno: true });
    } catch (e) {
        console.warn('Warning: failed to save usuario to Firestore', e.message || e);
    }
    return id;
}

async function obtenerUsuarioPorCredenciales(usuario, clave) {
    try {
        console.log('===> Query obtenerUsuarioPorCredenciales args:', { usuario, clave });
        const [rows] = await pool.query(
            'SELECT id, usuario, rol, clinica_id, dueno, clave FROM usuarios WHERE usuario=? LIMIT 1',
            [usuario]
        );
        console.log('===> Filas encontradas:', rows);
        if (!rows || rows.length === 0) return undefined;
        // Verificamos la clave aquí para poder loguear diferencias
        const row = rows[0];
        let match = false;
        if (typeof row.clave === 'string' && row.clave.startsWith('$2')) {
            // Stored as bcrypt hash
            match = await bcrypt.compare(clave, row.clave);
        } else {
            // Legacy plain-text password: compare directly and upgrade to hashed
            if (row.clave === clave) {
                match = true;
                try {
                    const newHash = await bcrypt.hash(clave, SALT_ROUNDS);
                    await pool.query('UPDATE usuarios SET clave=? WHERE id=?', [newHash, row.id]);
                    console.log('===> Password legacy upgraded to bcrypt for user id', row.id);
                } catch (e) {
                    console.error('Error al actualizar clave a hashed:', e);
                }
            } else {
                match = false;
            }
        }
        if (!match) {
            console.log('===> Clave no coincide. almacenada: <hidden>, recibida:', clave);
            return undefined;
        }
        // Devolver sin la clave
        delete row.clave;
        return row;
    } catch (err) {
        console.error('Error en obtenerUsuarioPorCredenciales:', err);
        throw err;
    }
}


// Actualizar usuario
async function actualizarUsuario(id, usuario, clinica_id) {
    const { usuario: nombre, clave, rol } = usuario;
    if (typeof clave !== 'undefined' && clave !== null && clave !== '') {
        const hashed = await bcrypt.hash(clave, SALT_ROUNDS);
                const [result] = await pool.query(
                        'UPDATE usuarios SET usuario=?, clave=?, rol=? WHERE id=? AND clinica_id=?',
                        [nombre, hashed, rol, id, clinica_id]
                );
                try {
                    await saveDoc('users', id, { usuario: nombre, rol, clinicaId: clinica_id || null });
                } catch (e) {
                    console.warn('Warning: failed to update usuario in Firestore', e.message || e);
                }
                return result.affectedRows;
    } else {
                const [result] = await pool.query(
                        'UPDATE usuarios SET usuario=?, rol=? WHERE id=? AND clinica_id=?',
                        [nombre, rol, id, clinica_id]
                );
                try {
                    await saveDoc('users', id, { usuario: nombre, rol, clinicaId: clinica_id || null });
                } catch (e) {
                    console.warn('Warning: failed to update usuario in Firestore', e.message || e);
                }
                return result.affectedRows;
    }
}

// Eliminar usuario
async function eliminarUsuario(id, clinica_id) {
    const [result] = await pool.query(
        'DELETE FROM usuarios WHERE id=? AND clinica_id=?',
        [id, clinica_id]
    );
        try {
            await deleteDoc('users', id);
        } catch (e) {
            console.warn('Warning: failed to delete usuario from Firestore', e.message || e);
        }
        return result.affectedRows;
}

module.exports = {
    obtenerUsuariosPorClinica,
    obtenerUsuarioPorId,
    crearUsuario,
    actualizarUsuario,
    eliminarUsuario,
    obtenerUsuarioPorCredenciales,
    vincularDoctorComoDueno,
    obtenerUsuarioPorFirebaseUid,
    crearUsuarioDesdeGoogle,
    actualizarEmailGoogle
};

// Expose helper to create clinic admin user
module.exports.crearUsuarioClinicaAdmin = crearUsuarioClinicaAdmin;
