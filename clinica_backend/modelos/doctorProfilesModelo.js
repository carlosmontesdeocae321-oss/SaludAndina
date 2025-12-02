const pool = require('../config/db');

async function obtenerPerfilPorUsuario(userId) {
  const [rows] = await pool.query('SELECT * FROM doctor_profiles WHERE user_id = ? LIMIT 1', [userId]);
  return rows[0] || null;
}

const { saveDoc } = require('../servicios/firebaseService');

async function crearPerfil(userId, data) {
  const { nombre, apellido, direccion, telefono, bio, avatar_url, email, especialidad } = data;
  const [result] = await pool.query(
    'INSERT INTO doctor_profiles (user_id, nombre, apellido, direccion, telefono, email, bio, avatar_url, especialidad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [userId, nombre, apellido, direccion, telefono, email, bio, avatar_url, especialidad]
  );
  const id = result.insertId;
  try {
    await saveDoc('doctor_profiles', userId, { userId, nombre, apellido, direccion, telefono, bio, avatar_url, email, especialidad });
  } catch (e) {
    console.warn('Warning: failed to save doctor_profile to Firestore', e.message || e);
  }
  return id;
}

async function actualizarPerfil(userId, data) {
  const fields = [];
  const values = [];
  ['nombre','apellido','direccion','telefono','email','bio','avatar_url','especialidad'].forEach(k => {
    if (Object.prototype.hasOwnProperty.call(data, k)) {
      fields.push(`${k} = ?`);
      values.push(data[k]);
    }
  });
  if (fields.length === 0) return 0;
  values.push(userId);
  const sql = `UPDATE doctor_profiles SET ${fields.join(', ')} WHERE user_id = ?`;
  const [res] = await pool.query(sql, values);
  try {
    const payload = {};
    fields.forEach((f, idx) => {
      const key = f.split('=')[0].trim();
      payload[key] = values[idx];
    });
    await saveDoc('doctor_profiles', userId, payload);
  } catch (e) {
    console.warn('Warning: failed to update doctor_profile in Firestore', e.message || e);
  }
  return res.affectedRows;
}

module.exports = {
  obtenerPerfilPorUsuario,
  crearPerfil,
  actualizarPerfil
};
