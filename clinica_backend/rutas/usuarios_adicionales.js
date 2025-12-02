const express = require('express');
const router = express.Router();
const usuariosModelo = require('../modelos/usuariosModelo');
const { getDoc, admin, initFirebase } = require('../servicios/firebaseService');
const { auth } = require('../middlewares/auth');

// Endpoint público para registrar/iniciar sesión con Google y crear doctor individual si no existe
router.post('/google-auth', async (req, res) => {
  try {
    const { idToken } = req.body || {};
    if (!idToken) {
      return res.status(400).json({ ok: false, message: 'Falta idToken' });
    }

    initFirebase();
    if (!admin || !admin.auth) {
      return res.status(500).json({ ok: false, message: 'Firebase no está configurado en el backend.' });
    }

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      console.error('google-auth verifyIdToken error:', e);
      return res.status(401).json({ ok: false, message: 'Token de Google inválido.' });
    }

    const firebaseUid = decoded.uid;
    const email = decoded.email || null;
    const displayName = decoded.name || null;

    let user = await usuariosModelo.obtenerUsuarioPorFirebaseUid(firebaseUid);
    if (!user) {
      user = await usuariosModelo.crearUsuarioDesdeGoogle({ firebaseUid, email, displayName });
    } else if (email && user.google_email !== email) {
      try {
        await usuariosModelo.actualizarEmailGoogle(user.id, email);
        user.google_email = email;
      } catch (e) {
        console.warn('No se pudo actualizar email google para usuario', user.id, e.message || e);
      }
    }

    return res.json({
      ok: true,
      data: {
        id: user.id,
        usuario: user.usuario,
        rol: user.rol,
        clinicaId: user.clinica_id,
        dueno: user.dueno === 1 || user.dueno === true,
        email: user.google_email || email,
        firebaseUid,
        authType: 'google'
      }
    });
  } catch (err) {
    console.error('Error en /api/usuarios/google-auth:', err);
    res.status(500).json({ ok: false, message: err.message || 'Error interno procesando Google Sign-In.' });
  }
});

// Endpoint para que el usuario (doctor) vea sus datos: número de pacientes y límite
// Protegemos sólo esta ruta con el middleware `auth` para evitar que el router
// en su conjunto requiera autenticación (esto interfería con /login cuando
// usuariosAdicionales se montaba antes que el router principal de usuarios).
router.get('/mis-datos', auth, async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ message: 'No autenticado' });
    const db = require('../config/db');
    const userInfo = { usuario: null, clinica: null, rol: req.user.rol, dueno: req.user.dueno === true };

    // Intentar obtener datos desde Firestore primero
    try {
      const userDoc = await getDoc('users', req.user.id);
      if (userDoc) {
        userInfo.usuario = userDoc.usuario || null;
        // preferimos el clinicaId desde userDoc si está
        if (typeof userDoc.clinicaId !== 'undefined') req.user.clinica_id = userDoc.clinicaId;
      }
    } catch (e) {
      // ignore firestore errors and fallback to DB
    }

    // Si no obtuvimos usuario desde Firestore, obtener nombre de usuario desde MySQL
    if (!userInfo.usuario) {
      const [urows] = await db.query('SELECT usuario FROM usuarios WHERE id = ? LIMIT 1', [req.user.id]);
      if (urows && urows[0]) userInfo.usuario = urows[0].usuario;
    }

    if (req.user.rol === 'doctor' && !req.user.clinica_id) {
      // Doctor individual -> contar pacientes por doctor y considerar compras individuales
      const [rows] = await db.query('SELECT COUNT(*) AS c FROM pacientes WHERE doctor_id = ?', [req.user.id]);
      const totalPacientes = rows[0] ? rows[0].c : 0;
      const comprasInd = require('../modelos/comprasPacientesIndividualModelo');
      const extra = await comprasInd.obtenerPacientesCompradosIndividual(req.user.id);
      const base = 20;
      const limite = Math.min(base + (extra || 0), 80);
      // Determinar si el doctor fue vinculado mediante compra (puede existir registro en compras_doctores)
      let esVinculado = false;
      let clinicaIdFromPurchase = null;
      try {
        const [prow] = await db.query('SELECT COUNT(*) AS c FROM compras_doctores WHERE usuario_id = ?', [req.user.id]);
        esVinculado = prow && prow[0] && prow[0].c > 0;
        // Si existe registro en compras_doctores y no tenemos clinica_id en el usuario,
        // intentar recuperar la clinica_id de la compra más reciente para proporcionar
        // un contexto coherente a la UI (mis-datos debe exponer clinicaId cuando corresponda).
        if (esVinculado) {
          try {
            const [crow] = await db.query('SELECT clinica_id FROM compras_doctores WHERE usuario_id = ? AND clinica_id IS NOT NULL ORDER BY id DESC LIMIT 1', [req.user.id]);
            if (crow && crow[0] && crow[0].clinica_id) {
              clinicaIdFromPurchase = crow[0].clinica_id;
              // No modificamos permanentemente la fila de usuario aquí, solo devolvemos el valor
              // para que la aplicación cliente muestre la pestaña Clínica y pueda operar en contexto.
            }
          } catch (e) {
            // fallback: ignorar error y no setear clinicaIdFromPurchase
            clinicaIdFromPurchase = null;
          }
        }
      } catch (e) {
        esVinculado = false;
      }
      // Devolver estructura consistente con la rama de clínica (incluye id/esVinculado).
      // Si encontramos una clínica asociada a través de compras_doctores, exponerla como `clinicaId`.
      const clinicaIdToReturn = req.user.clinica_id || clinicaIdFromPurchase || null;
      return res.json({ ...userInfo, id: req.user.id, rol: req.user.rol, clinicaId: clinicaIdToReturn, totalPacientes, limite, plan: null, extra, doctores: [], esVinculado });
    }

    // Para usuarios asociados a clínica (incluye owners), devolver info de plan y límites
    const plan = await require('../modelos/clinicaPlanesModelo').obtenerPlanDeClinica(req.user.clinica_id);
    const [rows] = await db.query('SELECT COUNT(*) AS c FROM pacientes WHERE clinica_id = ?', [req.user.clinica_id]);
    const totalPacientes = rows[0] ? rows[0].c : 0;
    const extra = await require('../modelos/comprasPacientesModelo').obtenerPacientesComprados(req.user.clinica_id);
    const limite = (plan?.pacientes_max || 0) + (extra || 0);

    // Obtener nombre de la clínica si existe
    if (req.user.clinica_id) {
      const [crows] = await db.query('SELECT nombre FROM clinicas WHERE id = ? LIMIT 1', [req.user.clinica_id]);
      if (crows && crows[0]) userInfo.clinica = crows[0].nombre;
    }

    // Obtener lista de doctores de la clínica (nombre y flags)
    let doctores = [];
    if (req.user.clinica_id) {
      // intentar obtener doctores desde Firestore si existe colección users con clinicaId
      try {
        // Simple approach: list users in Firestore is not efficient here; fall back to DB for now
        const [drows] = await db.query('SELECT id, usuario, dueno FROM usuarios WHERE clinica_id = ?', [req.user.clinica_id]);
        doctores = (drows || []).map(d => ({ id: d.id, usuario: d.usuario, dueno: d.dueno === 1 || d.dueno === true }));
      } catch (e) {
        doctores = [];
      }
    }

    // Determinar si el usuario fue vinculado mediante una compra de vinculación
    let esVinculado = false;
    try {
      const [prow] = await db.query('SELECT COUNT(*) AS c FROM compras_doctores WHERE usuario_id = ?', [req.user.id]);
      esVinculado = prow && prow[0] && prow[0].c > 0;
    } catch (e) {
      // ignorar error y asumir false
      esVinculado = false;
    }

    res.json({ ...userInfo, id: req.user.id, rol: req.user.rol, clinicaId: req.user.clinica_id, totalPacientes, limite, plan, extra, doctores, esVinculado });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
