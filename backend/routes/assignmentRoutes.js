const express = require('express');
const router = express.Router({ mergeParams: true });
const { getAssignments, getAssignment, createAssignment, updateAssignment, updateAssignmentStatus, deleteAssignment, getSubmissions } = require('../controllers/assignmentController');
const { submitAssignment, gradeSubmission, getMySubmission } = require('../controllers/submissionController');
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/', protect, getAssignments);
router.post('/', protect, authorize('admin', 'faculty'), createAssignment);
router.get('/:assignId', protect, getAssignment);
router.put('/:assignId', protect, authorize('admin', 'faculty'), updateAssignment);
router.patch('/:assignId/status', protect, updateAssignmentStatus);  // Kanban drag-drop
router.delete('/:assignId', protect, authorize('admin', 'faculty'), deleteAssignment);
router.post('/:assignId/submit', protect, authorize('student'), upload.single('file'), submitAssignment);
router.get('/:assignId/submissions', protect, authorize('admin', 'faculty'), getSubmissions);
router.get('/:assignId/my-submission', protect, authorize('student'), getMySubmission);
router.put('/submissions/:subId/grade', protect, authorize('admin', 'faculty'), gradeSubmission);

module.exports = router;

