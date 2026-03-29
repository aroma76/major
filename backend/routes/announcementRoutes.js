const express = require('express');
const router = express.Router({ mergeParams: true });
const { getAnnouncements, createAnnouncement, deleteAnnouncement } = require('../controllers/announcementController');
const { protect, authorize } = require('../middleware/auth');

router.get('/', protect, getAnnouncements);
router.post('/', protect, authorize('admin', 'faculty'), createAnnouncement);
router.delete('/:announcementId', protect, authorize('admin', 'faculty'), deleteAnnouncement);

module.exports = router;
