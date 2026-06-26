/**
 * localStorage.js
 * ───────────────
 * Local-disk fallback for file storage.
 * Activated automatically when STORAGE_PROVIDER=local in .env
 * or when Supabase is unreachable.
 *
 * Files are saved to:  backend/uploads/<folder>/<timestamp>-<originalname>
 * Served via:          GET /api/uploads/:folder/:filename  (see downloadRoutes)
 */

const path = require('path');
const fs   = require('fs');

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads', 'edusync');

// Ensure upload directory exists at startup
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

/**
 * Returns a public URL for a locally stored file.
 * In production this should be the server's own URL — reads from env.
 */
function getLocalPublicUrl(filename) {
  const baseUrl = process.env.SERVER_URL || `http://localhost:${process.env.PORT || 5000}`;
  return `${baseUrl}/api/uploads/edusync/${filename}`;
}

/**
 * Saves a Buffer to disk and returns the public URL.
 * @param {Buffer} buffer
 * @param {string} originalName
 * @returns {{ publicUrl: string, storagePath: string }}
 */
async function saveFileToDisk(buffer, originalName) {
  const safeName    = originalName.replace(/\s+/g, '_');
  const storageName = `${Date.now()}-${safeName}`;
  const filePath    = path.join(UPLOAD_DIR, storageName);

  await fs.promises.writeFile(filePath, buffer);

  return {
    publicUrl   : getLocalPublicUrl(storageName),
    storagePath : filePath,    // absolute path — used for deletion
  };
}

/**
 * Deletes a locally stored file.
 * @param {string} storagePath  Absolute path returned by saveFileToDisk
 */
async function deleteLocalFile(storagePath) {
  try {
    await fs.promises.unlink(storagePath);
  } catch (err) {
    // Non-fatal: file might already be gone
    console.warn('[LocalStorage] Could not delete file:', err.message);
  }
}

module.exports = { saveFileToDisk, deleteLocalFile, UPLOAD_DIR };
