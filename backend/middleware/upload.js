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

const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });
module.exports = upload;
