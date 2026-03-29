const express = require('express');
const router = express.Router({ mergeParams: true });
const { getMessages, sendMessage, pinMessage, deleteMessage, getPinnedMessages } = require('../controllers/messageController');
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/', protect, getMessages);
router.post('/', protect, upload.single('file'), sendMessage);
router.get('/pinned', protect, getPinnedMessages);
router.put('/:msgId/pin', protect, authorize('admin', 'faculty'), pinMessage);
router.delete('/:msgId', protect, deleteMessage);

module.exports = router;
