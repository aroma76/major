const express = require('express');
const router = express.Router({ mergeParams: true });
const { getNotes, uploadNote, deleteNote } = require('../controllers/fileController');
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/', protect, getNotes);
router.post('/', protect, authorize('admin', 'faculty'), upload.single('file'), uploadNote);
router.delete('/:noteId', protect, deleteNote);

module.exports = router;
