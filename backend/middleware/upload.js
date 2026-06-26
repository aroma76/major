const multer = require('multer');
const path   = require('path');
const fs     = require('fs');

// ─── Storage mode ────────────────────────────────────────────────────────────
// Set  STORAGE_PROVIDER=local  in .env to bypass Supabase entirely.
// Default is 'supabase' if the env var is not set.
const USE_LOCAL = (process.env.STORAGE_PROVIDER || 'supabase').toLowerCase() === 'local';

// Lazy-load so the server still boots even if Supabase creds are missing
let supabaseStorage = null;
let localStorageHelper = null;

if (!USE_LOCAL) {
  try {
    supabaseStorage = require('../config/supabase');
  } catch (e) {
    console.warn('[Upload] Supabase config failed — falling back to local disk:', e.message);
  }
}

if (USE_LOCAL || !supabaseStorage) {
  localStorageHelper = require('../config/localStorage');
}

const FOLDER = 'edusync';

// ─── Multer in-memory engine (common to both paths) ──────────────────────────
// We buffer the file in memory first, then persist it ourselves in _handleFile.

class DualStorage {
  async _handleFile(req, file, cb) {
    const chunks = [];
    file.stream.on('data', (chunk) => chunks.push(chunk));
    file.stream.on('error', cb);
    file.stream.on('end', async () => {
      try {
        const buffer  = Buffer.concat(chunks);
        const safeName = file.originalname.replace(/\s+/g, '_');

        // ── Supabase path ────────────────────────────────────────────────────
        if (!USE_LOCAL && supabaseStorage) {
          const { supabase, BUCKET } = supabaseStorage;
          const storagePath = `${FOLDER}/${Date.now()}-${safeName}`;

          const { error } = await supabase.storage
            .from(BUCKET)
            .upload(storagePath, buffer, {
              contentType: file.mimetype,
              upsert      : false,
            });

          if (error) {
            // Supabase failed at runtime — auto-fall through to local disk
            console.warn('[Upload] Supabase upload failed, saving locally:', error.message);
            return this._saveLocally(buffer, safeName, 'supabase_runtime_error', file, cb);
          }

          const { data } = supabase.storage.from(BUCKET).getPublicUrl(storagePath);

          return cb(null, {
            path       : data.publicUrl,
            filename   : file.originalname,
            size       : buffer.length,
            storagePath,                    // Supabase path (for future deletion)
            storageMode: 'supabase',
          });
        }

        // ── Local disk path ──────────────────────────────────────────────────
        return this._saveLocally(buffer, safeName, null, file, cb);

      } catch (err) {
        cb(err);
      }
    });
  }

  async _saveLocally(buffer, safeName, reason, file, cb) {
    try {
      if (!localStorageHelper) {
        localStorageHelper = require('../config/localStorage');
      }
      const { publicUrl, storagePath } = await localStorageHelper.saveFileToDisk(buffer, safeName);

      if (reason) {
        console.log(`[Upload] Saved locally (reason: ${reason}): ${storagePath}`);
      } else {
        console.log(`[Upload] Saved locally: ${storagePath}`);
      }

      return cb(null, {
        path       : publicUrl,
        filename   : file.originalname,
        size       : buffer.length,
        storagePath,                        // absolute disk path (for deletion)
        storageMode: 'local',
      });
    } catch (err) {
      cb(err);
    }
  }

  _removeFile(req, file, cb) {
    if (!file.storagePath) return cb(null);

    if (file.storageMode === 'supabase' && supabaseStorage) {
      supabaseStorage.supabase.storage
        .from(supabaseStorage.BUCKET)
        .remove([file.storagePath])
        .catch(() => {});
    } else if (file.storageMode === 'local') {
      if (localStorageHelper) {
        localStorageHelper.deleteLocalFile(file.storagePath).catch(() => {});
      }
    }

    cb(null);
  }
}

// ─── File filter: block executables ─────────────────────────────────────────
const fileFilter = (req, file, cb) => {
  const blockedMimes = [
    'application/x-msdownload',
    'application/x-bat',
    'application/x-msdos-program',
  ];
  if (blockedMimes.includes(file.mimetype)) {
    return cb(new Error('Executable files are not allowed for security reasons'), false);
  }
  cb(null, true);
};

const upload = multer({
  storage   : new DualStorage(),
  fileFilter,
  limits    : { fileSize: 50 * 1024 * 1024 }, // 50 MB
});

module.exports = upload;
