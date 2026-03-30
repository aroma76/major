const express = require('express');
const router = express.Router({ mergeParams: true });
const { protect } = require('../middleware/auth');
const { getNotes, createNote, deleteNote } = require('../controllers/notesController');

router.route('/')
  .get(protect, getNotes)
  .post(protect, createNote);

router.route('/:noteId')
  .delete(protect, deleteNote);

module.exports = router;
