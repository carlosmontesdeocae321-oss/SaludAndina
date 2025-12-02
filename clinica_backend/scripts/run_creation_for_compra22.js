const pool = require('../config/db');
const usuariosModelo = require('../modelos/usuariosModelo');

(async () => {
  try {
    const compraId = 22;
    const [rows] = await pool.query('SELECT id, titulo, usuario_id, status, clinica_id, extra_data FROM compras_promociones WHERE id = ? LIMIT 1', [compraId]);
    const compra = rows && rows[0] ? rows[0] : null;
    console.log('Compra row:', compra);
    if (!compra) throw new Error('Compra not found');
    if (compra.status !== 'completed') throw new Error('Compra not completed');
    if (compra.clinica_id) throw new Error('Compra already linked to clinica');
    let extra = null;
    try { extra = compra.extra_data ? (typeof compra.extra_data === 'object' ? compra.extra_data : JSON.parse(compra.extra_data)) : null; } catch (e) { extra = null; }
    const tituloLower = (compra.titulo || '').toString().toLowerCase();
    const looksLikeClinic = tituloLower.includes('clinica') || tituloLower.includes('clínica') || (extra && extra.nombre_clinica);
    if (!looksLikeClinic) throw new Error('Does not look like clinic');
    if (!extra || !extra.usuario || !extra.clave) throw new Error('Missing usuario/clave in extra');

    console.log('Creating clinica for compra', compraId);
    const [cRes] = await pool.query('INSERT INTO clinicas (nombre, direccion) VALUES (?, ?)', [extra.nombre_clinica || compra.titulo || 'Clínica', extra.direccion || null]);
    const clinicaId = cRes.insertId;
    console.log('Inserted clinica id:', clinicaId);

    console.log('Creating usuario via model:', extra.usuario);
    const userId = await usuariosModelo.crearUsuarioClinicaAdmin({ usuario: extra.usuario, clave: String(extra.clave), rol: 'clinica', clinica_id: clinicaId });
    console.log('Created usuario id:', userId);

    console.log('Linking usuario to clinica...');
    await pool.query('UPDATE usuarios SET clinica_id = ?, dueno = 1 WHERE id = ?', [clinicaId, userId]);
    await pool.query('UPDATE compras_promociones SET clinica_id = ? WHERE id = ?', [clinicaId, compraId]);
    console.log('Done.');
    process.exit(0);
  } catch (e) {
    console.error('Error running creation script:', e.message || e);
    process.exit(1);
  }
})();
