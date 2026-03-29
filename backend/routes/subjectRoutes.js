const express = require('express');
const router = express.Router();
const { getSubjects, getSubject, createSubject, updateSubject, deleteSubject, getSubjectMembers } = require('../controllers/subjectController');
const { protect, authorize } = require('../middleware/auth');

router.get('/', protect, getSubjects);
router.get('/:id', protect, getSubject);
router.post('/', protect, authorize('admin', 'faculty'), createSubject);
router.put('/:id', protect, authorize('admin', 'faculty'), updateSubject);
router.delete('/:id', protect, authorize('admin'), deleteSubject);
router.get('/:id/members', protect, getSubjectMembers);

module.exports = router;
