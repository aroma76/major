const express = require('express');
const router = express.Router();
const { getChannels, getChannel, createChannel, updateChannel, deleteChannel, getChannelMembers } = require('../controllers/channelController');
const { protect, authorize } = require('../middleware/auth');

router.get('/', protect, getChannels);
router.get('/:id', protect, getChannel);
router.post('/', protect, authorize('admin', 'faculty'), createChannel);
router.put('/:id', protect, authorize('admin', 'faculty'), updateChannel);
router.delete('/:id', protect, authorize('admin'), deleteChannel);
router.get('/:id/members', protect, getChannelMembers);

module.exports = router;
