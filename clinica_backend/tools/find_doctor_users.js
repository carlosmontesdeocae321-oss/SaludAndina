const { initFirebase, admin } = require('../servicios/firebaseService');

async function run() {
  initFirebase();
  const db = admin.firestore();
  try {
    const q = db.collection('users').where('rol', '>=', 'doctor').where('rol', '<=', 'doctor\uf8ff');
    const snap = await q.get();
    console.log(`Found ${snap.size} users with rol like 'doctor':`);
    snap.forEach(doc => console.log(doc.id, doc.data()));
  } catch (e) {
    console.error('Error querying Firestore users:', e.message || e);
    // fallback: list small sample from collection
    try {
      const c = await db.collection('users').limit(20).get();
      console.log('Sample users:');
      c.forEach(d => console.log(d.id, d.data()));
    } catch (e2) {
      console.error('Also failed to list sample users:', e2.message || e2);
    }
  }
}

if (require.main === module) run();
