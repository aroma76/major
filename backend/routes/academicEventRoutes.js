const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { getAcademicEvents, createAcademicEvent, updateAcademicEvent, deleteAcademicEvent } = require('../controllers/academicEventController');

router.get('/', protect, getAcademicEvents);
router.post('/', protect, createAcademicEvent);        // admin/teacher only in production
router.patch('/:id', protect, updateAcademicEvent);
router.delete('/:id', protect, deleteAcademicEvent);

module.exports = router;
