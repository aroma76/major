const express = require('express');
const router = express.Router();
const {
  getProjects, getProject, createProject, updateProgress,
  deleteProject, createTask, updateTaskStatus
} = require('../controllers/projectController');
const { protect } = require('../middleware/auth');

router.get('/',                              protect, getProjects);
router.post('/',                             protect, createProject);
router.get('/:id',                           protect, getProject);
router.patch('/:id/progress',               protect, updateProgress);
router.delete('/:id',                        protect, deleteProject);
router.post('/:id/tasks',                    protect, createTask);
router.patch('/:id/tasks/:taskId/status',   protect, updateTaskStatus);

module.exports = router;
