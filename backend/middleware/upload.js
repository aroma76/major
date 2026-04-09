const cloudinary = require('../config/cloudinary');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

const storage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => ({
    folder: 'adtu-collab',
    allowed_formats: ['jpg','jpeg','png','gif','pdf','doc','docx','ppt','pptx','xls','xlsx','txt','zip'],
    resource_type: 'auto',
    public_id: `${Date.now()}-${file.originalname.split('.')[0]}`,
  }),
});

const fileFilter = (req, file, cb) => {
  // Broad blocklist for obvious malware/scripts
  const blockedMimes = [
    'application/x-msdownload', // .exe
    'application/x-sh',         // .sh
    'application/javascript',   // .js
    'text/x-python',            // .py
    'application/x-bat',        // .bat
  ];
  if (blockedMimes.includes(file.mimetype)) {
    return cb(new Error('File type not allowed for security reasons'), false);
  }
  cb(null, true);
};

const upload = multer({ 
  storage, 
  fileFilter,
  limits: { fileSize: 50 * 1024 * 1024 } 
});
module.exports = upload;
