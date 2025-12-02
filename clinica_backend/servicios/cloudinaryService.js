const path = require('path');
const fs = require('fs');

// Cloudinary removed: local uploader fallback.
// This module provides a compatible `uploadFile(filePath, opts)` function
// that returns an object with `secure_url` so existing callers keep working.

async function uploadFile(filePath, _opts = {}) {
  // If the file is already under an `uploads` folder, return a public URL
  try {
    const normalized = path.normalize(filePath);
    const idx = normalized.lastIndexOf(path.sep + 'uploads' + path.sep);
    let rel;
    if (idx !== -1) {
      rel = normalized.substr(idx + 1).replace(/\\/g, '/');
    } else {
      // Move file to uploads/misc
      const uploadsDir = path.join(__dirname, '..', 'uploads', 'misc');
      try { fs.mkdirSync(uploadsDir, { recursive: true }); } catch (e) {}
      const filename = path.basename(filePath);
      const dest = path.join(uploadsDir, `${Date.now()}_${filename}`);
      try { fs.copyFileSync(filePath, dest); } catch (e) { /* ignore */ }
      rel = path.join('uploads', 'misc', path.basename(dest)).replace(/\\/g, '/');
    }

    return { secure_url: `/${rel}` };
  } catch (e) {
    // In case of any error, return a minimal fallback
    return { secure_url: '/uploads/placeholder.png' };
  }
}

module.exports = {
  uploadFile
};
