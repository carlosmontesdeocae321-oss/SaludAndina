const pool = require('../config/db');

async function main() {
  try {
    const [users] = await pool.query('SELECT id, usuario, rol, clinica_id FROM usuarios WHERE usuario IN (?, ?, ?) ORDER BY usuario', ['keli', 'jan', 'jan ']);
    console.log('Usuarios:', users);

    const doctor = users.find(u => u.usuario === 'keli');
    if (doctor) {
      const [indRows] = await pool.query(
        'SELECT id, doctor_id, fecha_compra, monto FROM compras_pacientes_individual WHERE doctor_id = ? ORDER BY id DESC LIMIT 5',
        [doctor.id]
      );
      const [indCountRows] = await pool.query(
        'SELECT COUNT(*) AS total FROM compras_pacientes_individual WHERE doctor_id = ?',
        [doctor.id]
      );
      console.log('Compras individuales recientes:', indRows);
      console.log('Total compras individuales:', indCountRows[0]);
    } else {
      console.log('Doctor keli no encontrado');
    }

    const clinic = users.find(u => u.usuario.trim() === 'jan');
    if (clinic) {
      const clinicaId = clinic.clinica_id || clinic.id;
      const [clinicRows] = await pool.query(
        'SELECT id, clinica_id, fecha_compra, monto FROM compras_pacientes WHERE clinica_id = ? ORDER BY id DESC LIMIT 5',
        [clinicaId]
      );
      const [clinicCount] = await pool.query(
        'SELECT COUNT(*) AS total FROM compras_pacientes WHERE clinica_id = ?',
        [clinicaId]
      );
      console.log('Compras clínica recientes:', clinicRows);
      console.log('Total compras clínica:', clinicCount[0]);
    } else {
      console.log('Usuario jan no encontrado o sin clinica_id');
    }

    const [pendingPromos] = await pool.query('SELECT id, titulo, usuario_id, clinica_id, status, cantidad, extra_data FROM compras_promociones ORDER BY id DESC LIMIT 5');
    console.log('Ultimas compras_promociones:', pendingPromos.map(row => {
      console.log('extra_data raw type', typeof row.extra_data, row.extra_data);
      let extra = null;
      if (row.extra_data) {
        try {
          if (typeof row.extra_data === 'object' && !Buffer.isBuffer(row.extra_data)) {
            extra = row.extra_data;
          } else {
            extra = JSON.parse(row.extra_data.toString());
          }
        } catch (err) {
          extra = row.extra_data.toString();
        }
      }
      return {
        ...row,
        extra_data: extra
      };
    }));

    await pool.end();
  } catch (err) {
    console.error('Error debug_slots:', err);
    process.exitCode = 1;
  }
}

main();
