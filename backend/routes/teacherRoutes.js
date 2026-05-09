const express = require('express');
const router = express.Router();
const { getTeacherStats, getTeacherRecentActivity, getStudentRecentActivity } = require('../controllers/teacherController');
const { protect, authorize } = require('../middleware/auth');

router.get('/stats',            protect, authorize('faculty', 'admin'), getTeacherStats);
router.get('/recent-activity',  protect, authorize('faculty', 'admin'), getTeacherRecentActivity);
router.get('/student-activity', protect,                                getStudentRecentActivity);

module.exports = router;
