const pool = require('../config/db');

async function crearDocumento(userId, data) {
  const { filename, path: filePath, url } = data;
  const [res] = await pool.query(
    'INSERT INTO doctor_documents (user_id, filename, path, url, creado_en) VALUES (?, ?, ?, ?, NOW())',
    [userId, filename, filePath, url]
  );
  const id = res.insertId;
  try {
    const { saveDoc } = require('../servicios/firebaseService');
    await saveDoc('doctor_documents', id, { userId, filename, path: filePath, url });
  } catch (e) {
    console.warn('Warning: failed to save doctor_document to Firestore', e.message || e);
  }
  return id;
}

async function listarDocumentosPorUsuario(userId) {
  const [rows] = await pool.query('SELECT id, filename, path, url, creado_en FROM doctor_documents WHERE user_id = ? ORDER BY creado_en DESC', [userId]);
  return rows;
}

module.exports = {
  crearDocumento,
  listarDocumentosPorUsuario
};
