const pool = require('../config/db');

async function main() {
  try {
    const doctorId = Number(process.argv[2]) || 20;
    const clinicaId = Number(process.argv[3]) || 15;

    const [[{ c: totalPacientes }]] = await pool.query('SELECT COUNT(*) AS c FROM pacientes WHERE doctor_id = ?', [doctorId]);
    const [[{ total: extraDoctor }]] = await pool.query('SELECT COUNT(*) AS total FROM compras_pacientes_individual WHERE doctor_id = ?', [doctorId]);
    const limiteDoctor = Math.min(20 + (extraDoctor || 0), 80);

    const [[{ c: totalPacientesClinica }]] = await pool.query('SELECT COUNT(*) AS c FROM pacientes WHERE clinica_id = ?', [clinicaId]);
    const [[{ total: extraClinica }]] = await pool.query('SELECT COUNT(*) AS total FROM compras_pacientes WHERE clinica_id = ?', [clinicaId]);
    const planSql = `
      SELECT p.pacientes_max
      FROM clinica_planes cp
      JOIN planes p ON p.id = cp.plan_id
      WHERE cp.clinica_id = ? AND cp.activo = 1
      ORDER BY cp.id DESC LIMIT 1
    `;
    const [planRows] = await pool.query(planSql, [clinicaId]);
    const basePlan = planRows.length ? Number(planRows[0].pacientes_max) : 0;
    const limiteClinica = basePlan + (extraClinica || 0);

    console.log({ totalPacientes, extraDoctor, limiteDoctor, totalPacientesClinica, extraClinica, basePlan, limiteClinica });
  } catch (err) {
    console.error('Error compute_limits:', err);
    process.exitCode = 1;
  } finally {
    try {
      await pool.end();
    } catch (_) {}
  }
}

main();
