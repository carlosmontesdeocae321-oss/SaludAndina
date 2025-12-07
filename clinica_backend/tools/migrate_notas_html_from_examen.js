const pool = require('../config/db');

async function migrate() {
  console.log('Starting migration: populate notas_html from examen_* fields (detecting available columns)');
  try {
    // Discover which examen_* columns actually exist in the historial table
    const [cols] = await pool.query("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'historial'");
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    const candidateFields = [
      { col: 'examen_piel', label: 'Piel' },
      { col: 'examen_cabeza', label: 'Cabeza' },
      { col: 'examen_ojos', label: 'Ojos' },
      { col: 'examen_nariz', label: 'Nariz' },
      { col: 'examen_boca', label: 'Boca' },
      { col: 'examen_oidos', label: 'Oídos' },
      { col: 'examen_orofaringe', label: 'Orofaringe' },
      { col: 'examen_cuello', label: 'Cuello' },
      { col: 'examen_torax', label: 'Tórax' },
      { col: 'examen_campos_pulm', label: 'Campos pulmonares' },
      { col: 'examen_ruidos_card', label: 'Ruidos cardíacos' },
      { col: 'examen_abdomen', label: 'Abdomen' },
      { col: 'examen_extremidades', label: 'Extremidades' },
      { col: 'examen_neuro', label: 'Sistema neurológico' }
    ];

    const available = candidateFields.filter(f => existing.has(f.col));
    if (available.length === 0) {
      console.log('No examen_* columns found in historial. Nothing to migrate.');
      process.exit(0);
    }

    // Build SELECT dynamically
    const selectCols = ['id', ...available.map(f => f.col)];
    // include some optional supporting columns if present
    ['otros','diagnostico','tratamiento','receta'].forEach(c => { if (existing.has(c)) selectCols.push(c); });

    const sql = `SELECT ${selectCols.join(', ')} FROM historial WHERE notas_html IS NULL OR notas_html = ""`;
    const [rows] = await pool.query(sql);
    console.log('Found', rows.length, 'rows to process');
    let updated = 0;
    for (const r of rows) {
      const parts = [];
      for (const f of available) {
        const val = r[f.col];
        if (val) parts.push(`<p><strong>${f.label}:</strong> ${val}</p>`);
      }

      if (r.otros) parts.push(`<h4>Observaciones</h4><p>${r.otros}</p>`);
      if (r.diagnostico) parts.push(`<h4>Diagnóstico</h4><p>${r.diagnostico}</p>`);
      if (r.tratamiento) parts.push(`<h4>Tratamiento</h4><p>${r.tratamiento}</p>`);
      if (r.receta) parts.push(`<h4>Receta</h4><p>${r.receta}</p>`);

      const notas = parts.join('\n');
      if (!notas) continue;
      await pool.query('UPDATE historial SET notas_html = ? WHERE id = ?', [notas, r.id]);
      updated++;
    }
    console.log('Migration finished. Updated rows:', updated);
    process.exit(0);
  } catch (e) {
    console.error('Migration error', e);
    process.exit(1);
  }
}

migrate();
