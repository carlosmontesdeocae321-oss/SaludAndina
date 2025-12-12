const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { auth } = require('../middlewares/auth');
const { validarLimiteDoctores } = require('../utils/validacionLimites');
const usuariosModelo = require('../modelos/usuariosModelo');
const pacientesModelo = require('../modelos/pacientesModelo');

// Vincular doctor individual y sus pacientes a una clínica
router.post('/vincular-doctor', auth, async (req, res) => {
  const { doctor_id, clinica_id } = req.body;
  if (!doctor_id || !clinica_id) {
    return res.status(400).json({ error: 'doctor_id y clinica_id son obligatorios' });
  }
  try {
    // Solo el dueño de la clínica (dueno) o la cuenta tipo 'clinica' asociada pueden vincular doctores a su clínica
    // Normalizar valores: en BD `dueno` puede venir como 1/0 o true/false; clinica_id también puede ser string/number.
    const isOwner = req.user && (req.user.dueno === true || Number(req.user.dueno) === 1);
    const userClinicaId = req.user ? Number(req.user.clinica_id) : null;
    const targetClinicaId = Number(clinica_id);
    if (!req.user || ((!isOwner) && req.user.rol !== 'clinica') || userClinicaId !== targetClinicaId) {
      return res.status(403).json({ error: 'Solo el dueño de la clínica puede vincular doctores' });
    }
    // Usar transacción para evitar estados parciales
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      // Verificar que el doctor existe y no es dueño de otra clínica
      const [drows] = await conn.query('SELECT id, clinica_id, dueno FROM usuarios WHERE id = ? LIMIT 1', [doctor_id]);
      if (!drows || !drows[0]) {
        await conn.rollback(); conn.release();
        return res.status(404).json({ error: 'Doctor no encontrado' });
      }
      const doc = drows[0];
      if (doc.dueno === 1 || doc.dueno === true) {
        await conn.rollback(); conn.release();
        return res.status(400).json({ error: 'No se puede vincular a un doctor que es dueño de una clínica' });
      }
      // Validar límite de doctores para la clínica
      const { validarLimiteDoctores } = require('../utils/validacionLimites');
      const validacion = await validarLimiteDoctores(clinica_id);
      if (!validacion.permitido) {
        await conn.rollback(); conn.release();
        return res.status(403).json({ error: 'Límite de doctores alcanzado para el plan actual. Compre un plan superior.' });
      }
      // Registrar pago único de $10
      await conn.query('INSERT INTO compras_doctores (clinica_id, usuario_id, fecha_compra, monto) VALUES (?, ?, NOW(), ?)', [clinica_id, doctor_id, 10]);
      // Asociar el doctor a la clínica y asegurarnos dueno=0
      await conn.query('UPDATE usuarios SET clinica_id = ?, dueno = 0 WHERE id = ?', [clinica_id, doctor_id]);
      // Migrar pacientes del doctor a la clínica (dejando doctor_id para referencia)
      await conn.query('UPDATE pacientes SET clinica_id = ? WHERE doctor_id = ?', [clinica_id, doctor_id]);
      await conn.commit(); conn.release();
      return res.json({ success: true, mensaje: 'Doctor y pacientes vinculados correctamente.' });
    } catch (txErr) {
      try { await conn.rollback(); } catch (e) {}
      conn.release();
      console.error('Error en transacción de vinculación:', txErr);
      return res.status(500).json({ error: 'Error al vincular doctor y pacientes.' });
    }
  } catch (err) {
    res.status(500).json({ error: 'Error al vincular doctor y pacientes.' });
  }
});

module.exports = router;

// Desvincular doctor (el doctor puede solicitar desvincularse de su clínica)
router.post('/desvincular-doctor', auth, async (req, res) => {
  try {
    if (!req.user || req.user.rol !== 'doctor' || !req.user.clinica_id) {
      return res.status(403).json({ error: 'Solo doctores vinculados pueden desvincularse' });
    }
    const doctorId = req.user.id;
    // Sólo permitir desvinculación si el doctor se vinculó mediante una compra (registro en compras_doctores)
    try {
      const [rows] = await db.query('SELECT COUNT(*) AS c FROM compras_doctores WHERE usuario_id = ?', [doctorId]);
      const comprados = rows && rows[0] ? rows[0].c : 0;
      if (!comprados || comprados === 0) {
        // Doctor fue creado por la clínica (no puede desvincularse)
        return res.status(403).json({ error: 'Los doctores creados por la clínica no pueden desvincularse' });
      }
    } catch (e) {
      console.error('Error comprobando compras_doctores:', e);
      return res.status(500).json({ error: 'Error interno al comprobar estado de vinculación' });
    }

    // No migramos pacientes: los pacientes que ya fueron migrados quedan en la clínica
    await db.query('UPDATE usuarios SET clinica_id = NULL WHERE id = ?', [doctorId]);
    // Además, remover registros históricos de compras_doctores para que el usuario
    // deje de ser considerado "vinculado" por comprobantes anteriores.
    try {
      await db.query('DELETE FROM compras_doctores WHERE usuario_id = ?', [doctorId]);
    } catch (e) {
      console.warn('Error eliminando compras_doctores al desvincular:', e.message || e);
    }
    return res.json({ success: true, mensaje: 'Desvinculación realizada' });
  } catch (err) {
    console.error('Error al desvincular doctor:', err);
    return res.status(500).json({ error: 'Error al desvincular doctor' });
  }
});
