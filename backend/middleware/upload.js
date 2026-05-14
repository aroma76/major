const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

/**
 * Determines the correct Cloudinary resource_type for a file.
 * - 'image' → Images only (jpg, png, gif, etc.)
 * - 'raw'   → Everything else: PDFs, docx, pptx, zip, txt, etc.
 *
 * PDFs must NOT use 'image' type — when fl_attachment is applied to an
 * image-delivery PDF URL, Cloudinary runs its image transformation pipeline
 * which returns a malformed HTTP response (ERR_INVALID_RESPONSE in Chrome).
 * With 'raw' type, fl_attachment works reliably.
 */
const getResourceType = (ext) => {
  const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
  if (imageExts.includes(ext)) return 'image';
  return 'raw'; // PDFs, docs, pptx, zip, txt, code files, etc.
};

const storage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => {
    const ext = (file.originalname.split('.').pop() || '').toLowerCase();
    return {
      folder: 'adtu-collab',
      allowed_formats: [
        // Images
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
        // Documents
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
        // Code & text
        'txt', 'md', 'py', 'js', 'ts', 'dart', 'java', 'c', 'cpp', 'cs', 'go', 'rb',
        'json', 'xml', 'csv', 'yaml', 'yml', 'ipynb', 'sh',
        // Archives
        'zip', 'rar', '7z',
      ],
      resource_type: getResourceType(ext),
      type: 'upload',   // Force public delivery — prevents 401 "Unauthorized" errors
      public_id: `${Date.now()}-${file.originalname.replace(/\.[^.]+$/, '')}`,
    };
  },
});

const fileFilter = (req, file, cb) => {
  // Block only genuine malware/executable types
  const blockedMimes = [
    'application/x-msdownload', // .exe
    'application/x-bat',        // .bat
    'application/x-msdos-program',
  ];
  if (blockedMimes.includes(file.mimetype)) {
    return cb(new Error('Executable files are not allowed for security reasons'), false);
  }
  cb(null, true);
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 },
});

module.exports = upload;
