const pool = require('../config/db');
const usuariosModelo = require('../modelos/usuariosModelo');

// 🔹 Middleware de autenticación
async function auth(req, res, next) {
    const usuario = req.headers['x-usuario'];
    const clave = req.headers['x-clave'];
    const firebaseUid = req.headers['x-firebase-uid'];

    if (!usuario || !clave) {
        if (!firebaseUid) {
            console.warn('[auth] Faltan credenciales - path:', req.path, 'method:', req.method, 'headers:', {
                keys: Object.keys(req.headers)
            });
            return res.status(401).json({ message: 'Faltan credenciales' });
        }

        try {
            const user = await usuariosModelo.obtenerUsuarioPorFirebaseUid(firebaseUid);
            if (!user) {
                console.warn('[auth] Firebase UID no reconocido:', firebaseUid, 'path:', req.path);
                return res.status(401).json({ message: 'Credenciales inválidas' });
            }

            req.user = {
                id: user.id,
                rol: user.rol,
                clinica_id: user.clinica_id,
                dueno: user.dueno === 1 || user.dueno === true
            };

            return next();
        } catch (err) {
            console.error('[auth] Error interno verificando Firebase UID:', err);
            return res.status(500).json({ message: err.message });
        }
    }

    try {
        // Reutilizar la lógica del modelo que compara (y migra) contraseñas correctamente
        const user = await usuariosModelo.obtenerUsuarioPorCredenciales(usuario, clave);
        if (!user) {
            console.warn('[auth] Credenciales fallaron para usuario:', usuario, 'path:', req.path);
            return res.status(401).json({ message: 'Usuario o clave incorrecta' });
        }

        req.user = {
            id: user.id,
            rol: user.rol,
            clinica_id: user.clinica_id,
            dueno: user.dueno === 1 || user.dueno === true
        };

        next();
    } catch (err) {
        console.error('[auth] Error interno:', err);
        res.status(500).json({ message: err.message });
    }
}

// 🔹 Middleware para filtrar por clínica
function filtroClinica(req, res, next) {
    if (!req.user || !req.user.clinica_id) {
        return res.status(403).json({ message: 'Acceso no permitido' });
    }

    req.clinica_id = req.user.clinica_id;
    next();
}

module.exports = {
    auth,
    filtroClinica
};
