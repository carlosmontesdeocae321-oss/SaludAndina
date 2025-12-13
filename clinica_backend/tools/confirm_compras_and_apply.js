#!/usr/bin/env node
/**
 * Script de utilidad: lista compras pendientes, las confirma y aplica efectos
 * (creación de clínica + vinculación de usuario cuando extra_data provee datos).
 * Uso: desde carpeta `clinica_backend` ejecutar `node tools/confirm_compras_and_apply.js`
 */
const pagosService = require('../servicios/pagosService');
const pool = require('../config/db');
const usuariosModelo = require('../modelos/usuariosModelo');
const { resolvePlanFromTitle, assignPlanToClinic, getPlanSpecBySlug } = require('../utils/planHelper');

function parseJsonField(raw) {
  if (!raw) return null;
  if (typeof raw === 'string') {
    try { return JSON.parse(raw); } catch (e) { return null; }
  }
  if (typeof raw === 'object') return raw;
  try { return JSON.parse(String(raw)); } catch (e) { return null; }
}

async function ensureComprasDoctoresTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS compras_doctores (
        id INT AUTO_INCREMENT PRIMARY KEY,
        clinica_id INT NOT NULL,
        usuario_id INT NOT NULL,
        fecha_compra TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        monto DECIMAL(10,2) DEFAULT NULL
      ) ENGINE=InnoDB;
    `);
  } catch (e) {
    console.warn('No se pudo asegurar tabla compras_doctores:', e.message || e);
  }
}

async function process() {
  console.log('Iniciando: listar compras pendientes...');
  const pendientes = await pagosService.listarComprasPendientes();
  if (!pendientes || pendientes.length === 0) {
    console.log('No hay compras pendientes. Fin.');
    return;
  }

  console.log(`Encontradas ${pendientes.length} compras pendientes.`);
  for (const c of pendientes) {
    try {
      console.log('-> Procesando compra id=', c.id, 'titulo=', c.titulo, 'usuario_id=', c.usuario_id, 'clinica_id=', c.clinica_id);
      const ok = await pagosService.confirmarCompra({ compraId: c.id });
      console.log(`   confirmarCompra(${c.id}) => ${ok}`);

      // Re-obtener compra
      const compraFull = await pagosService.obtenerCompra(c.id);
      if (!compraFull) continue;

      // Si compra completada y sin clinica creada, intentar crearla si parece ser de tipo clinica
      if ((compraFull.status || '').toString().toLowerCase() === 'completed' && !compraFull.clinica_id) {
        const extra = parseJsonField(compraFull.extra_data);
        const tituloLower = (compraFull.titulo || '').toString().toLowerCase();
        const looksLikeClinic = tituloLower.includes('clinica') || tituloLower.includes('clínica') || (extra && (extra.nombre_clinica || extra.nombre));
        if (!looksLikeClinic) {
          console.log('   compra no parece crear clínica, salto creación de clínica.');
          continue;
        }

        const nombreClinica = (extra && (extra.nombre_clinica || extra.nombre)) ? (extra.nombre_clinica || extra.nombre) : (compraFull.titulo || 'Clínica');
        const direccion = (extra && (extra.direccion || extra.direccion_clinica)) ? (extra.direccion || extra.direccion_clinica) : '';
        console.log('   Creando clinica:', nombreClinica, direccion);
        const [cRes] = await pool.query('INSERT INTO clinicas (nombre, direccion) VALUES (?, ?)', [nombreClinica, direccion]);
        const clinicaId = cRes.insertId;
        console.log('   clinica creada id=', clinicaId);

        // Determinar usuario a vincular
        let usuarioParaVincular = null;
        let createdUsuarioId = null;
        try {
          if (extra && extra.usuario) {
            const [found] = await pool.query('SELECT id FROM usuarios WHERE usuario = ? LIMIT 1', [extra.usuario]);
            if (found && found[0]) {
              usuarioParaVincular = found[0].id;
              createdUsuarioId = usuarioParaVincular;
            } else if (extra.clave) {
              try {
                const id = await usuariosModelo.crearUsuarioClinicaAdmin({ usuario: extra.usuario, clave: String(extra.clave), rol: 'clinica', clinica_id: clinicaId });
                usuarioParaVincular = id;
                createdUsuarioId = id;
              } catch (e) {
                console.warn('   error creando usuario desde extra:', e.message || e);
              }
            }
          }
        } catch (e) { console.warn('   error buscando/creando usuario desde extra:', e.message || e); }

        if (!usuarioParaVincular) {
          usuarioParaVincular = compraFull.usuario_id || null;
        }

        if (!usuarioParaVincular) {
          console.log('   no hay usuario para vincular, actualizando compra.clinica_id sin vincular usuario');
          try { await pool.query('UPDATE compras_promociones SET clinica_id = ? WHERE id = ?', [clinicaId, compraFull.id]); } catch (e) { console.warn('   error update compra.clinica_id', e.message || e); }
          continue;
        }

        // Obtener rol del usuario destino
        const [uRows] = await pool.query('SELECT id, rol, dueno FROM usuarios WHERE id = ? LIMIT 1', [usuarioParaVincular]);
        const uRow = uRows && uRows[0] ? uRows[0] : null;
        try {
          if (uRow && (uRow.rol === 'doctor')) {
            // Vincular como doctor (dueno = 0)
            await ensureComprasDoctoresTable();
            try {
              await pool.query('UPDATE usuarios SET clinica_id = ?, dueno = 0 WHERE id = ?', [clinicaId, usuarioParaVincular]);
            } catch (e) { console.warn('   error actualizando usuario doctor:', e.message || e); }
            try {
              await pool.query('INSERT INTO compras_doctores (clinica_id, usuario_id, fecha_compra, monto) VALUES (?, ?, NOW(), ?)', [clinicaId, usuarioParaVincular, compraFull.monto || null]);
            } catch (e) { console.warn('   error insert compras_doctores:', e.message || e); }
            try {
              await pool.query('UPDATE pacientes SET clinica_id = ? WHERE doctor_id = ?', [clinicaId, usuarioParaVincular]);
            } catch (e) { console.warn('   error migrando pacientes del doctor:', e.message || e); }
            if (!createdUsuarioId) createdUsuarioId = usuarioParaVincular;
            console.log('   usuario vinculado como doctor y cupo reservado');
          } else {
            // Vincular como dueño/administrador de la clinica
            try {
              await pool.query('UPDATE usuarios SET clinica_id = ?, dueno = 1 WHERE id = ?', [clinicaId, usuarioParaVincular]);
            } catch (e) { console.warn('   error actualizando usuario como dueño:', e.message || e); }
            if (!createdUsuarioId) createdUsuarioId = usuarioParaVincular;
            console.log('   usuario vinculado como dueño de la clínica');
          }
        } catch (e) { console.warn('   error durante vinculación:', e.message || e); }

        try { await pool.query('UPDATE compras_promociones SET clinica_id = ? WHERE id = ?', [clinicaId, compraFull.id]); } catch (e) { console.warn('   error update compra.clinica_id final', e.message || e); }

        // Intentar asignar plan si aplica
        const planSpec = resolvePlanFromTitle(compraFull.titulo || '') || getPlanSpecBySlug('clinica_pequena');
        if (planSpec) {
          try {
            await assignPlanToClinic({ clinicaId, planSpec });
            console.log('   plan asignado:', planSpec.slug);
          } catch (e) { console.warn('   error asignando plan:', e.message || e); }
        }
      }
    } catch (err) {
      console.error('Error procesando compra id=', c.id, err);
    }
  }
  console.log('Fin del procesamiento.');
}

process().catch(e => {
  console.error('Error general script:', e);
  process.exit(1);
});
