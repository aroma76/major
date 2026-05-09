const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

const storage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => {
    const ext = (file.originalname.split('.').pop() || '').toLowerCase();
    // PDFs must use resource_type 'image' — Cloudinary serves them with
    // correct Content-Type: application/pdf so the browser can open them.
    // All other non-image files use 'auto' or 'raw'.
    const pdfExts    = ['pdf'];
    const imageExts  = ['jpg','jpeg','png','gif','webp','bmp','svg'];
    let resourceType = 'auto';
    if (pdfExts.includes(ext))   resourceType = 'image';   // delivers real PDF
    if (imageExts.includes(ext)) resourceType = 'image';

    return {
      folder: 'adtu-collab',
      allowed_formats: [
        // Images
        'jpg','jpeg','png','gif','webp','bmp','svg',
        // Documents
        'pdf','doc','docx','ppt','pptx','xls','xlsx',
        // Code & text
        'txt','md','py','js','ts','dart','java','c','cpp','cs','go','rb',
        'json','xml','csv','yaml','yml','ipynb','sh',
        // Archives
        'zip','rar','7z',
      ],
      resource_type: resourceType,
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
  limits: { fileSize: 50 * 1024 * 1024 } 
});
module.exports = upload;
