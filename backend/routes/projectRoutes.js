const express = require('express');
const router = express.Router();
const {
  getProjects, getProject, createProject,
  getClassroomStudents, addMember, removeMember,
  updateProgress, deleteProject,
  createTask, updateTask, updateTaskStatus, deleteTask,
} = require('../controllers/projectController');
const { protect } = require('../middleware/auth');

router.get('/',                                protect, getProjects);
router.post('/',                               protect, createProject);
router.get('/:id',                             protect, getProject);
router.patch('/:id/progress',                  protect, updateProgress);
router.delete('/:id',                          protect, deleteProject);

// ── Member management ─────────────────────────────────────────────────────────
router.get('/:id/students',                    protect, getClassroomStudents);
router.post('/:id/members',                    protect, addMember);
router.delete('/:id/members/:userId',          protect, removeMember);

// ── Tasks ─────────────────────────────────────────────────────────────────────
router.post('/:id/tasks',                      protect, createTask);
router.patch('/:id/tasks/:taskId',             protect, updateTask);
router.patch('/:id/tasks/:taskId/status',      protect, updateTaskStatus);
router.delete('/:id/tasks/:taskId',            protect, deleteTask);

module.exports = router;
