#!/usr/bin/env node
const mysql = require('mysql2/promise');
const { URL } = require('url');

if (process.argv.length < 3) {
  console.error('Usage: node migrate_with_url.js "mysql://user:pass@host:port/db"');
  process.exit(2);
}

const connUrl = process.argv[2];

async function migrateWithUrl(connUrl) {
  try {
    const u = new URL(connUrl);
    const config = {
      host: u.hostname,
      port: u.port || 3306,
      user: decodeURIComponent(u.username),
      password: decodeURIComponent(u.password),
      database: u.pathname.replace(/^\//, ''),
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
    };

    console.log('Connecting to', config.host + ':' + config.port, 'database', config.database);
    const pool = await mysql.createPool(config);

    // Discover columns
    const [cols] = await pool.query("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'historial'", [config.database]);
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    console.log('Found columns:', Array.from(existing).slice(0,50).join(', '));

    // Ensure notas_html column exists; if not, create it
    if (!existing.has('notas_html')) {
      console.log('`notas_html` column not found; creating column...');
      await pool.query('ALTER TABLE historial ADD COLUMN notas_html TEXT NULL');
      console.log('`notas_html` column created');
      // update existing set
      existing.add('notas_html');
    } else {
      console.log('`notas_html` column already exists');
    }

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

    const selectCols = ['id', ...available.map(f => f.col)];
    ['otros','diagnostico','tratamiento','receta'].forEach(c => { if (existing.has(c)) selectCols.push(c); });

    const sql = `SELECT ${selectCols.join(', ')} FROM historial WHERE notas_html IS NULL OR notas_html = ""`;
    console.log('Running:', sql.replace(/\s+/g, ' ').substring(0,200));
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
    await pool.end();
    process.exit(0);
  } catch (e) {
    console.error('Migration error', e);
    process.exit(1);
  }
}

migrateWithUrl(connUrl);
