const express = require('express');
const router = express.Router();
const {
  getProjects, getProject, createProject, updateProgress, updateMembers,
  deleteProject, createTask, updateTask, updateTaskStatus, deleteTask,
} = require('../controllers/projectController');
const { protect } = require('../middleware/auth');

router.get('/',                              protect, getProjects);
router.post('/',                             protect, createProject);
router.get('/:id',                           protect, getProject);
router.patch('/:id/progress',               protect, updateProgress);
router.patch('/:id/members',                protect, updateMembers);
router.delete('/:id',                        protect, deleteProject);
router.post('/:id/tasks',                    protect, createTask);
router.patch('/:id/tasks/:taskId',          protect, updateTask);
router.patch('/:id/tasks/:taskId/status',   protect, updateTaskStatus);
router.delete('/:id/tasks/:taskId',         protect, deleteTask);

module.exports = router;
