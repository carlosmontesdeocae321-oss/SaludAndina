const fs = require('fs');
const path = require('path');

async function main() {
  try {
    const saPath = path.join(__dirname, '..', 'config', 'saludandina-f0fad-firebase-adminsdk-fbsvc-3080dc07cc.json');
    if (!fs.existsSync(saPath)) {
      console.error('Service account JSON not found at', saPath);
      process.exit(1);
    }
    const serviceAccount = require(saPath);
    const projectId = serviceAccount.project_id;
    if (!projectId) {
      console.error('project_id not found in service account JSON');
      process.exit(1);
    }
    // Determine bucket name: CLI --bucket or env BUCKET_NAME or deduced project_id.appspot.com
    const argvBucket = (() => {
      const idx = process.argv.findIndex(a => a === '--bucket');
      if (idx !== -1 && process.argv.length > idx + 1) return process.argv[idx+1];
      // also accept first positional arg
      if (process.argv.length > 2 && !process.argv[2].startsWith('--')) return process.argv[2];
      return null;
    })();
    const bucketName = process.env.BUCKET_NAME || argvBucket || `${projectId}.appspot.com`;
    console.log('Attempting to create bucket:', bucketName);

    const { Storage } = require('@google-cloud/storage');
    const storage = new Storage({ projectId, credentials: serviceAccount });

    // Check if bucket exists
    const [buckets] = await storage.getBuckets({ prefix: bucketName });
    const exists = buckets.some(b => b.name === bucketName);
    if (exists) {
      console.log('Bucket already exists:', bucketName);
      return;
    }

    // Create bucket
    await storage.createBucket(bucketName, { location: 'US', storageClass: 'STANDARD' });
    console.log('Bucket created:', bucketName);
  } catch (e) {
    console.error('Error creating bucket:', e.message || e);
    process.exit(1);
  }
}

main();
