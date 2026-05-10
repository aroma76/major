const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

/**
 * Determines the correct Cloudinary resource_type for a file.
 * - 'image' → Images AND PDFs (Cloudinary serves PDFs with correct MIME type under image delivery)
 * - 'raw'   → Everything else (docx, pptx, zip, txt, etc.)
 * Using 'auto' is avoided because it causes 501 errors when Cloudinary
 * auto-assigns 'raw' but the returned URL still uses the '/image/upload/' path.
 */
const getResourceType = (ext) => {
  const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
  const pdfExts   = ['pdf'];
  if (imageExts.includes(ext) || pdfExts.includes(ext)) return 'image';
  return 'raw'; // docx, pptx, xls, zip, txt, py, etc.
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
