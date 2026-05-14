const multer = require('multer');
const { supabase, BUCKET } = require('../config/supabase');

const FOLDER = 'adtu-collab';

/**
 * Custom multer storage engine that streams uploaded files directly to
 * Supabase Storage and returns the public URL as req.file.path.
 *
 * This maintains full backward-compatibility with existing controllers
 * (they still read req.file.path for the file URL — no changes needed there).
 */
class SupabaseStorage {
  async _handleFile(req, file, cb) {
    const chunks = [];
    file.stream.on('data', (chunk) => chunks.push(chunk));
    file.stream.on('error', cb);
    file.stream.on('end', async () => {
      try {
        const buffer = Buffer.concat(chunks);
        // Sanitise filename: replace spaces and keep extension
        const safeName = file.originalname.replace(/\s+/g, '_');
        const storagePath = `${FOLDER}/${Date.now()}-${safeName}`;

        const { error } = await supabase.storage
          .from(BUCKET)
          .upload(storagePath, buffer, {
            contentType: file.mimetype,
            upsert: false,
          });

        if (error) return cb(error);

        // Build public URL — Supabase format for public buckets:
        // {SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}
        const { data } = supabase.storage
          .from(BUCKET)
          .getPublicUrl(storagePath);

        cb(null, {
          path        : data.publicUrl,   // ← used by controllers as file URL
          filename    : file.originalname,
          size        : buffer.length,
          storagePath,                     // ← Supabase path (for deletion later)
        });
      } catch (err) {
        cb(err);
      }
    });
  }

  _removeFile(req, file, cb) {
    if (file.storagePath) {
      supabase.storage.from(BUCKET).remove([file.storagePath]).catch(() => {});
    }
    cb(null);
  }
}

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
  storage  : new SupabaseStorage(),
  fileFilter,
  limits   : { fileSize: 50 * 1024 * 1024 }, // 50 MB
});

module.exports = upload;
