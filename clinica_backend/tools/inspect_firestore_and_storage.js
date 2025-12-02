const { initFirebase, admin } = require('../servicios/firebaseService');
const { Storage } = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

async function listCollections() {
  initFirebase();
  const db = admin.firestore();
  const collections = await db.listCollections();
  console.log('Collections found:', collections.map(c => c.id));
  for (const c of collections) {
    const snap = await c.get();
    console.log(`- ${c.id}: ${snap.size} documents`);
    const docs = snap.docs.slice(0, 3).map(d => ({ id: d.id, data: d.data() }));
    console.log('  Samples:', docs);
  }
}

async function listStorageObjects() {
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET;
  if (!bucketName) {
    console.warn('FIREBASE_STORAGE_BUCKET not set; skipping storage inspection');
    return;
  }

  // Try to construct Storage client using the service account JSON if available
  let storage;
  try {
    const saPath = path.join(__dirname, '..', 'config', 'saludandina-f0fad-firebase-adminsdk-fbsvc-3080dc07cc.json');
    if (fs.existsSync(saPath)) {
      const serviceAccount = require(saPath);
      storage = new Storage({ projectId: serviceAccount.project_id, credentials: serviceAccount });
    } else {
      // Fallback to default credentials (env/ADC)
      storage = new Storage();
    }
  } catch (e) {
    console.warn('Could not initialize Storage client with service account JSON, falling back to ADC:', e.message || e);
    storage = new Storage();
  }

  const bucket = storage.bucket(bucketName);
  const [files] = await bucket.getFiles({ maxResults: 200 });
  console.log(`Storage objects in ${bucketName}: ${files.length}`);
  const samples = files.slice(0, 10).map(f => ({ name: f.name, publicUrl: `https://storage.googleapis.com/${bucketName}/${f.name}` }));
  console.log('Samples:', samples);
}

async function run() {
  try {
    await listCollections();
    await listStorageObjects();
  } catch (e) {
    console.error('Error inspecting Firestore/Storage:', e.message || e);
  }
}

run();
