const express = require('express');
const router = express.Router();
const { enroll, unenroll, getMyEnrollments, bulkEnroll } = require('../controllers/enrollmentController');
const { protect, authorize } = require('../middleware/auth');

router.get('/my', protect, getMyEnrollments);
router.post('/', protect, authorize('admin', 'faculty'), enroll);
router.delete('/', protect, authorize('admin', 'faculty'), unenroll);
router.post('/bulk', protect, authorize('admin'), bulkEnroll);

module.exports = router;
