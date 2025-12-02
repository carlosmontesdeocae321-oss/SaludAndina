const express = require('express');
const router = express.Router();
const db = require('../config/db');

// Obtener todos los usuarios (admin)
router.get('/', async (req, res) => {
  try {
    // Use LEFT JOIN to get email from doctor_profiles when available.
    // Some installations keep email in doctor_profiles rather than usuarios.
    // Añadimos una columna calculada `es_de_clinica` que indica si el
    // usuario está vinculado/creado por una clínica o es dueño. Devolvemos
    // también `creado_por_clinica` para compatibilidad con clientes.
    // Ordenamos de forma que los usuarios individuales (es_de_clinica = 0)
    // aparezcan primero y los de clínica (es_de_clinica = 1) queden al final.
    // Use subqueries/EXISTS to avoid duplicating users when JOINing compras_doctores
    // (cada compra podría generar una fila adicional). Esto garantiza una fila
    // por usuario y calcula las flags `creado_por_clinica` y `es_de_clinica`
    // de forma consistente.
    const sql = `
      SELECT
        u.id,
        u.usuario AS nombre,
        dp.email AS email,
        u.clinica_id AS clinicaId,
        u.rol,
        u.dueno AS dueno,
        -- creado_por_clinica = tiene clinica_id pero NO tiene registro en compras_doctores
        CASE WHEN u.clinica_id IS NOT NULL AND NOT EXISTS(
          SELECT 1 FROM compras_doctores cd2 WHERE cd2.usuario_id = u.id
        ) THEN 1 ELSE 0 END AS creado_por_clinica,
        -- es_de_clinica = indica relación ACTUAL con la clínica: tiene clinica_id o es dueño
        -- No basamos este flag en registros históricos de compras (compras_doctores),
        -- porque las compras se mantienen tras una desvinculación y eso haría que
        -- un doctor desvinculado siguiera apareciendo como 'de clínica'.
        CASE WHEN u.clinica_id IS NOT NULL OR u.dueno = 1 THEN 1 ELSE 0 END AS es_de_clinica
      FROM usuarios u
      LEFT JOIN doctor_profiles dp ON dp.user_id = u.id
      -- No hacemos LEFT JOIN directo a compras_doctores para evitar filas duplicadas
      ORDER BY es_de_clinica ASC, u.usuario ASC
    `;
    const [rows] = await db.query(sql);
    res.json(rows);
  } catch (err) {
    console.error('Error en /api/usuarios_admin GET:', err);
    res.status(500).json({ error: 'Error al obtener usuarios' });
  }
});

// Crear usuario (admin) — acepta creación sin email y usa el modelo compartido
router.post('/', async (req, res) => {
  const { nombre, email, password, clinicaId, rol } = req.body;
  if (!nombre || !password || !clinicaId || !rol) {
    return res.status(400).json({ error: 'Faltan datos obligatorios' });
  }
  try {
    // Si se está creando un doctor para una clínica, validar límite
    if (rol === 'doctor' && clinicaId) {
      try {
        const { validarLimiteDoctores } = require('../utils/validacionLimites');
        const validacion = await validarLimiteDoctores(clinicaId);
        if (!validacion.permitido) {
          return res.status(403).json({ error: 'Límite de doctores alcanzado para el plan actual. Compre un slot o cambie el plan.' });
        }
      } catch (vErr) {
        console.error('Error validando límite de doctores:', vErr);
        return res.status(500).json({ error: 'Error interno validando límites' });
      }
    }

    // Usar el modelo de usuarios para mantener consistencia
    const usuariosModelo = require('../modelos/usuariosModelo');
    // Mapear campos del admin: 'nombre' -> 'usuario', 'password' -> 'clave'
    const nuevoId = await usuariosModelo.crearUsuario({
      usuario: nombre,
      clave: password,
      rol: rol,
      clinica_id: clinicaId,
      dueno: 0,
    });
    res.status(201).json({ id: nuevoId, nombre, clinicaId, rol });
  } catch (err) {
    // Si la DB devuelve duplicado, devolver mensaje claro
    if (err && err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ error: 'El usuario ya existe' });
    }
    res.status(500).json({ error: 'Error al crear usuario', detail: err.message });
  }
});

module.exports = router;
