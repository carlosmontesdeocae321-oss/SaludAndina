const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const { saveDoc } = require('../servicios/firebaseService');

async function createAdmin() {
  const usuario = 'gaelivar';
  const clave = '1234';
  const rol = 'admin';
  try {
    const hashed = await bcrypt.hash(clave, 10);
    // Insert directly into usuarios table
    const [res] = await pool.query('INSERT INTO usuarios (usuario, clave, rol, dueno) VALUES (?, ?, ?, ?)', [usuario, hashed, rol, 0]);
    const id = res.insertId;
    console.log('Admin creado con id', id);
    try {
      await saveDoc('users', id, { usuario, rol, clinicaId: null, dueno: false });
      console.log('Documento Firestore creado para user', id);
    } catch (e) {
      console.warn('No se pudo crear doc en Firestore:', e.message || e);
    }
    process.exit(0);
  } catch (e) {
    console.error('Error creando admin:', e);
    process.exit(1);
  }
}

createAdmin();
