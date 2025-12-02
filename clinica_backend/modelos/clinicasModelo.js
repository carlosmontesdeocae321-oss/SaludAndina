const pool = require('../config/db');

async function listarClinicas() {
  const [rows] = await pool.query('SELECT id, nombre, direccion, imagen_url, telefono_contacto FROM clinicas ORDER BY id DESC');
  return rows;
}

async function obtenerClinicaPorId(id) {
  const [rows] = await pool.query('SELECT id, nombre, direccion, imagen_url, telefono_contacto FROM clinicas WHERE id = ? LIMIT 1', [id]);
  return rows && rows[0] ? rows[0] : null;
}

async function crearClinica({ nombre, direccion, telefono_contacto, imagen_url }) {
  const [result] = await pool.query('INSERT INTO clinicas (nombre, direccion, telefono_contacto, imagen_url) VALUES (?, ?, ?, ?)', [nombre, direccion || '', telefono_contacto || null, imagen_url || null]);
  return result.insertId;
}

async function actualizarClinica(id, campos) {
  const keys = Object.keys(campos || {}).filter(k => ['nombre', 'direccion', 'telefono_contacto', 'imagen_url'].includes(k));
  if (!keys.length) return 0;
  const sets = keys.map(k => `${k} = ?`).join(', ');
  const values = keys.map(k => campos[k]);
  values.push(id);
  const sql = `UPDATE clinicas SET ${sets} WHERE id = ?`;
  const [res] = await pool.query(sql, values);
  return res.affectedRows;
}

async function eliminarClinica(id) {
  const [res] = await pool.query('DELETE FROM clinicas WHERE id = ?', [id]);
  return res.affectedRows;
}

async function estadisticasBasicas(id) {
  // Conteo simple: pacientes, doctores (usuarios), citas
  const [pacientes] = await pool.query('SELECT COUNT(*) AS total FROM pacientes WHERE clinica_id = ?', [id]);
  const [doctores] = await pool.query("SELECT COUNT(*) AS total FROM usuarios WHERE clinica_id = ? AND rol = 'doctor'", [id]);
  const [citas] = await pool.query('SELECT COUNT(*) AS total FROM citas WHERE clinica_id = ?', [id]);
  return {
    pacientes: pacientes && pacientes[0] ? pacientes[0].total : 0,
    doctores: doctores && doctores[0] ? doctores[0].total : 0,
    citas: citas && citas[0] ? citas[0].total : 0,
  };
}

module.exports = {
  listarClinicas,
  obtenerClinicaPorId,
  crearClinica,
  actualizarClinica,
  eliminarClinica,
  estadisticasBasicas,
};
