const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Inicializa firebase-admin usando (en orden):
// 1) la variable GOOGLE_APPLICATION_CREDENTIALS (ADC)
// 2) el archivo en `clinica_backend/config/saludandina-...json` si existe
// 3) FIREBASE_SERVICE_ACCOUNT_PATH o FIREBASE_SERVICE_ACCOUNT_BASE64
// Si no encuentra credenciales, inicializa en modo fallback (puede fallar).
let _initialized = false;
let _bucket = null;

function initFirebase() {
  if (_initialized) return;

  let serviceAccount = null;
  // Preferir ADC
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    try {
      admin.initializeApp({});
      _initialized = true;
    } catch (e) {
      // ignore and try other methods
    }
  }

  if (!_initialized) {
    // Intentar archivo conocido en config
    try {
      const tryPath = path.join(__dirname, '..', 'config', 'saludandina-f0fad-firebase-adminsdk-fbsvc-3080dc07cc.json');
      if (fs.existsSync(tryPath)) {
        serviceAccount = require(tryPath);
      }
    } catch (e) {
      // ignore
    }
  }

  if (!_initialized && !serviceAccount) {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
    if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
      serviceAccount = require(serviceAccountPath);
    } else if (serviceAccountBase64) {
      try {
        const json = Buffer.from(serviceAccountBase64, 'base64').toString('utf8');
        serviceAccount = JSON.parse(json);
      } catch (e) {
        console.error('FIREBASE_SERVICE_ACCOUNT_BASE64 inválido', e);
      }
    }
  }

  if (serviceAccount) {
    const deducedBucket = process.env.FIREBASE_STORAGE_BUCKET || (serviceAccount.project_id ? `${serviceAccount.project_id}.appspot.com` : undefined);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: deducedBucket,
    });
    _initialized = true;
  }

  if (!_initialized) {
    console.warn('No se pudo inicializar Firebase admin con credenciales detectadas. Asegura GOOGLE_APPLICATION_CREDENTIALS o el archivo de service account.');
    return;
  }

  try {
    _bucket = admin.storage ? admin.storage().bucket(process.env.FIREBASE_STORAGE_BUCKET) : null;
  } catch (e) {
    _bucket = null;
    console.warn('No se pudo inicializar bucket de Firebase Storage:', e.message || e);
  }
}

async function uploadFile(filePath, destination) {
  initFirebase();
  if (!_bucket) throw new Error('Firebase Storage no inicializado: falta FIREBASE_STORAGE_BUCKET o credenciales');
  const options = { destination };
  await _bucket.upload(filePath, options);
  const file = _bucket.file(destination);
  // Hacer público para obtener URL pública
  try {
    await file.makePublic();
  } catch (e) {
    // ignore
  }
  return {
    publicUrl: `https://storage.googleapis.com/${_bucket.name}/${destination}`,
    path: destination
  };
}

async function uploadBuffer(buffer, destination, contentType) {
  initFirebase();
  if (!_bucket) throw new Error('Firebase Storage no inicializado: falta FIREBASE_STORAGE_BUCKET o credenciales');
  const file = _bucket.file(destination);
  const stream = file.createWriteStream({ metadata: { contentType } });
  return new Promise((resolve, reject) => {
    stream.on('error', (err) => reject(err));
    stream.on('finish', async () => {
      try {
        await file.makePublic();
      } catch (e) {}
      resolve({ publicUrl: `https://storage.googleapis.com/${_bucket.name}/${destination}`, path: destination });
    });
    stream.end(buffer);
  });
}

function getFirestore() {
  initFirebase();
  try {
    return admin.firestore();
  } catch (e) {
    throw new Error('Firestore no inicializado: ' + (e.message || e));
  }
}

// Helpers para Firestore
async function saveDoc(collection, id, data) {
  const db = getFirestore();
  const ref = db.collection(collection).doc(String(id));
  await ref.set(data, { merge: true });
  return ref;
}

function newBatch() {
  const db = getFirestore();
  return db.batch();
}

async function commitBatch(batch) {
  return batch.commit();
}

async function getDoc(collection, id) {
  const db = getFirestore();
  const ref = db.collection(collection).doc(String(id));
  const snap = await ref.get();
  if (!snap.exists) return null;
  return snap.data();
}

async function findInCollectionByField(collection, field, value) {
  try {
    const db = getFirestore();
    const q = db.collection(collection).where(field, '==', value).limit(1);
    const snap = await q.get();
    if (snap.empty) return null;
    const doc = snap.docs[0];
    return Object.assign({ id: doc.id }, doc.data());
  } catch (e) {
    // If Firestore not initialized or other error, bubble up to caller
    console.warn('firebaseService.findInCollectionByField error:', e.message || e);
    return null;
  }
}

async function deleteDoc(collection, id) {
  const db = getFirestore();
  const ref = db.collection(collection).doc(String(id));
  await ref.delete();
}

// Enviar notificaciones FCM
async function sendFCMToTopic(topic, messagePayload) {
  initFirebase();
  if (!admin.messaging) throw new Error('Firebase Messaging no disponible');
  const message = Object.assign({}, messagePayload, { topic });
  return admin.messaging().send(message);
}

async function sendFCMToTokens(tokens, messagePayload) {
  initFirebase();
  if (!admin.messaging) throw new Error('Firebase Messaging no disponible');
  const message = Object.assign({}, messagePayload);
  return admin.messaging().sendMulticast(Object.assign({ tokens }, message));
}

module.exports = {
  initFirebase,
  uploadFile,
  uploadBuffer,
  admin,
  // Firestore helpers
  saveDoc,
  newBatch,
  commitBatch,
  getDoc,
  deleteDoc
  ,
  // FCM helpers
  sendFCMToTopic,
  sendFCMToTokens
};


