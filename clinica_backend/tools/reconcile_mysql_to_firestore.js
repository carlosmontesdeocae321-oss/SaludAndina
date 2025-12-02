const pool = require('../config/db');
const fs = require('fs');
const path = require('path');
const firebase = require('../servicios/firebaseService');

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run') || args.includes('-n');
  const tablesArg = args.find(a => a.startsWith('--tables='));
  const tables = tablesArg ? tablesArg.split('=')[1].split(',') : null;
  const batchSizeArg = args.find(a => a.startsWith('--batch-size='));
  const batchSize = batchSizeArg ? parseInt(batchSizeArg.split('=')[1], 10) : 100;

  console.log('[reconcile] Iniciando reconciliación MySQL -> Firestore', dryRun ? '(dry-run)' : '');

  const mapping = [
    { table: 'usuarios', collection: 'users', idField: 'id' },
    { table: 'pacientes', collection: 'patients', idField: 'id' },
    { table: 'citas', collection: 'appointments', idField: 'id' },
    { table: 'historial', collection: 'medical_history', idField: 'id' },
    { table: 'doctor_profiles', collection: 'doctor_profiles', idField: 'id' },
    { table: 'doctor_documents', collection: 'doctor_documents', idField: 'id' },
    { table: 'clinicas', collection: 'clinics', idField: 'id' }
  ];

  for (const map of mapping) {
    if (tables && !tables.includes(map.table)) continue;
    console.log(`[reconcile] Procesando tabla: ${map.table} -> colección: ${map.collection}`);
    try {
      const [rows] = await pool.query(`SELECT * FROM ${map.table}`);
      console.log(`[reconcile] Registros encontrados en ${map.table}: ${rows.length}`);
      for (let i = 0; i < rows.length; i += batchSize) {
        const batch = rows.slice(i, i + batchSize);
        for (const row of batch) {
          const id = row[map.idField];
          const existing = await firebase.getDoc(map.collection, id).catch(() => null);
          if (!existing) {
            console.log(`[reconcile] Falta doc ${map.collection}/${id}`);
            if (!dryRun) {
              const doc = transformRow(map.table, row);
              // Si el documento contiene referencias a archivos locales, intentar subirlos
              await handleFileUploads(map.table, doc);
              await firebase.saveDoc(map.collection, id, doc);
              console.log(`[reconcile] Creado doc ${map.collection}/${id}`);
            }
          }
        }
      }
    } catch (e) {
      console.error(`[reconcile] Error procesando ${map.table}:`, e.message || e);
    }
  }

  console.log('[reconcile] Finalizado');
  process.exit(0);
}

function transformRow(table, row) {
  // Transformaciones mínimas: convertir fechas a ISO y nombres de campos simples.
  const out = { ...row };
  for (const k of Object.keys(out)) {
    if (out[k] instanceof Date) {
      out[k] = out[k].toISOString();
    }
  }
  // Normalizaciones específicas
  if (table === 'usuarios') {
    out.usuario = out.usuario || out.username || out.email;
    out.clinicaId = out.clinica_id || out.clinicaId || null;
  }
  if (table === 'clinicas') {
    out.imagen_url = out.imagen_url || out.imagenUrl || null;
  }
  if (table === 'doctor_profiles') {
    out.avatar_url = out.avatar_url || out.avatarUrl || null;
  }
  return out;
}

async function handleFileUploads(table, doc) {
  // Busca campos plausibles que apunten a archivos locales y los sube
  const candidateFields = ['imagen_url', 'imagenUrl', 'avatar_url', 'avatarUrl', 'path', 'url', 'filename'];
  for (const f of candidateFields) {
    if (!(f in doc)) continue;
    const val = doc[f];
    if (!val || typeof val !== 'string') continue;
    // Si parece ser una URL pública de storage, saltar
    if (val.startsWith('http://') || val.startsWith('https://')) continue;
    // Resolver ruta local
    let localPath = val;
    if (!path.isAbsolute(localPath)) {
      // Probar desde raíz del proyecto y desde carpeta uploads
      const cand1 = path.join(__dirname, '..', '..', localPath);
      const cand2 = path.join(__dirname, '..', '..', 'uploads', localPath);
      if (fs.existsSync(cand1)) localPath = cand1;
      else if (fs.existsSync(cand2)) localPath = cand2;
      else continue;
    }
    if (!fs.existsSync(localPath)) continue;
    try {
      const bucketPath = `${table}/${Date.now()}-${path.basename(localPath)}`;
      console.log(`[reconcile] Subiendo archivo ${localPath} -> ${bucketPath}`);
      const res = await firebase.uploadFile(localPath, bucketPath).catch(e => { console.warn('uploadFile failed', e && e.message); return null; });
      if (res && res.publicUrl) {
        // actualizar doc con la URL pública
        if (f.toLowerCase().includes('avatar') || f.toLowerCase().includes('imagen')) {
          doc[f] = res.publicUrl;
        } else if (f === 'path' || f === 'filename') {
          doc.url = res.publicUrl;
        } else {
          doc[f] = res.publicUrl;
        }
      }
    } catch (e) {
      console.warn('[reconcile] Error subiendo archivo:', e.message || e);
    }
  }
}

if (require.main === module) main();
