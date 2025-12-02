function filtroClinica(req, res, next) {
    if (!req.user) {
        return res.status(403).json({ message: 'Acceso no permitido' });
    }
    // Si el usuario es admin global, permite clinica_id del body para POST /usuarios
    if (req.user.rol === 'admin' && req.method === 'POST' && req.path === '/') {
        req.clinica_id = req.body.clinica_id || req.user.clinica_id;
    } else {
        // Permitir doctores individuales sin clinica_id: intentamos deducir una clinica
        // si el doctor compró una vinculación (registro en compras_doctores). Esto permite
        // que un doctor 'vinculado' (esVinculado) agregue pacientes a la clínica aunque
        // el dueño aún no haya ejecutado la acción final de vinculación.
        if (!req.user.clinica_id) {
            if (req.user.rol === 'doctor') {
                try {
                    const db = require('../config/db');
                    // Buscar la compra de vinculación más reciente para este usuario
                    // y usar su clinica_id como contexto si existe.
                    db.query('SELECT clinica_id FROM compras_doctores WHERE usuario_id = ? ORDER BY id DESC LIMIT 1', [req.user.id])
                        .then(([rows]) => {
                            if (rows && rows[0] && rows[0].clinica_id) {
                                req.clinica_id = rows[0].clinica_id;
                            } else {
                                req.clinica_id = null;
                            }
                            next();
                        })
                        .catch((e) => {
                            // Si falla la consulta, no rompemos el flujo: tratamos al doctor como individual
                            req.clinica_id = null;
                            next();
                        });
                    return; // salimos porque next se llamará desde la promesa
                } catch (e) {
                    req.clinica_id = null;
                }
            } else if (req.user.rol === 'clinica') {
                req.clinica_id = null;
            } else {
                return res.status(403).json({ message: 'Acceso no permitido' });
            }
        } else {
            req.clinica_id = req.user.clinica_id;
        }
    }
    next();
}

module.exports = filtroClinica;
