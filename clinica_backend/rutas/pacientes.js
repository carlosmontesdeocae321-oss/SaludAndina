const express = require('express');
const router = express.Router();
const pacientesControlador = require('../controladores/pacientesControlador');
const { auth } = require('../middlewares/auth');
const filtroClinica = require('../middlewares/clinica');
const pacientesModelo = require('../modelos/pacientesModelo');
const pool = require('../config/db');

// --- Rutas públicas (no requieren auth) ---
// Añadimos un limitador simple en memoria para evitar abusos
const lookupRate = new Map(); // ip -> { count, windowStart }
const LOOKUP_WINDOW_MS = 60 * 1000; // 1 minuto
const LOOKUP_MAX = 30; // máximo peticiones por ventana

function checkLookupRate(req, res, next) {
    try {
        const ip = req.ip || req.connection.remoteAddress || 'unknown';
        const now = Date.now();
        const entry = lookupRate.get(ip);
        if (!entry || now - entry.windowStart > LOOKUP_WINDOW_MS) {
            lookupRate.set(ip, { count: 1, windowStart: now });
            return next();
        }
        if (entry.count >= LOOKUP_MAX) {
            return res.status(429).json({ message: 'Too many requests, try again later' });
        }
        entry.count++;
        lookupRate.set(ip, entry);
        return next();
    } catch (e) {
        return next();
    }
}

// Obtener pacientes por doctor individual
router.get('/doctor/:doctor_id', async (req, res) => {
    const doctorId = req.params.doctor_id;
    try {
        const pacientes = await pacientesModelo.obtenerPacientesPorDoctor(doctorId);
        res.json(pacientes);
    } catch (err) {
        res.status(500).json({ error: 'Error al obtener pacientes por doctor' });
    }
});

/* =====================================================
   RUTAS ESPECÍFICAS
   ===================================================== */

// Buscar paciente global (público, con rate-limit)
router.get('/cedula/:cedula/global', checkLookupRate, async (req, res) => {
    try {
        const paciente = await pacientesModelo.obtenerPacientePorCedulaGlobal(req.params.cedula);
        if (!paciente) return res.status(404).json({ mensaje: 'Paciente no encontrado' });
        res.json(paciente);
    } catch (error) {
        console.error("ERROR BUSCAR PACIENTE GLOBAL", error);
        res.status(500).json({ error: "Error al obtener paciente global" });
    }
});

// Obtener pacientes por clínica
router.get('/clinica/:clinica_id', async (req, res) => {
    try {
        const [rows] = await pool.query(
            'SELECT * FROM pacientes WHERE clinica_id = ? ORDER BY id DESC',
            [req.params.clinica_id]
        );
        res.json(rows);
    } catch (error) {
        console.error("ERROR GET PACIENTES POR CLÍNICA:", error);
        res.status(500).json({ error: "Error obteniendo pacientes por clínica" });
    }
});

// Buscar paciente por cédula en la clínica del doctor (público, con rate-limit)
router.get('/cedula/:cedula', checkLookupRate, async (req, res) => {
    try {
        const paciente = await pacientesModelo.obtenerPacientePorCedula(req.params.cedula);
        if (!paciente) return res.status(404).json({ message: 'Paciente no encontrado' });
        res.json(paciente);
    } catch (error) {
        console.error("ERROR BUSCAR PACIENTE", error);
        res.status(500).json({ error: "Error al obtener paciente" });
    }
});

// A partir de aquí aplicamos autenticación y filtro de clínica para el resto de rutas
router.use(auth);
router.use(filtroClinica);

/* =====================================================
   RUTAS GENERALES
   ===================================================== */
router.get('/', pacientesControlador.listarPacientes);
router.get('/:id', pacientesControlador.verPaciente);
router.post('/', pacientesControlador.crearPaciente);
router.put('/:id', pacientesControlador.actualizarPaciente);
router.delete('/:id', pacientesControlador.eliminarPaciente);

module.exports = router;
