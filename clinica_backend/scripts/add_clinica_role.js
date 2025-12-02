const pool = require('../config/db');
(async () => {
  try {
    console.log('Altering usuarios.rol to add "clinica"...');
    // Fetch current enum definition
    const [col] = await pool.query("SHOW COLUMNS FROM usuarios LIKE 'rol'");
    const type = col && col[0] ? col[0].Type : null;
    console.log('Current rol type:', type);
    // Build new enum including existing values plus 'clinica'
    // Conservative approach: explicitly set desired set
    const newType = "ENUM('admin','doctor','paciente','clinica')";
    await pool.query(`ALTER TABLE usuarios MODIFY rol ${newType} NOT NULL DEFAULT 'doctor'`);
    console.log('Altered rol column successfully.');
    process.exit(0);
  } catch (e) {
    console.error('Error altering rol column:', e);
    process.exit(1);
  }
})();
