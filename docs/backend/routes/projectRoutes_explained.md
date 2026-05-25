# 📄 `routes/projectRoutes.js` — Complete Explanation

**File Path:** `backend/routes/projectRoutes.js`
**Lines:** 18
**Mounted at:** `app.use('/api/projects', projectRoutes)`
**Role:** Project and task management — CRUD for projects + nested task creation and status updates.

---

## 1. Full Source Code

```js
const express = require('express');
const router = express.Router();

const {
  getProjects, getProject, createProject, updateProgress,
  deleteProject, createTask, updateTaskStatus
} = require('../controllers/projectController');

const { protect } = require('../middleware/auth');

router.get('/',                            protect, getProjects);
router.post('/',                           protect, createProject);
router.get('/:id',                         protect, getProject);
router.patch('/:id/progress',             protect, updateProgress);
router.delete('/:id',                      protect, deleteProject);
router.post('/:id/tasks',                  protect, createTask);
router.patch('/:id/tasks/:taskId/status', protect, updateTaskStatus);
```

---

## 2. Route Table

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/projects` | List all projects for the current user |
| `POST` | `/api/projects` | Create a new project |
| `GET` | `/api/projects/:id` | Get project details (with tasks) |
| `PATCH` | `/api/projects/:id/progress` | Update project progress (0.0–1.0) |
| `DELETE` | `/api/projects/:id` | Delete a project |
| `POST` | `/api/projects/:id/tasks` | Create a task under a project |
| `PATCH` | `/api/projects/:id/tasks/:taskId/status` | Update a task's status |

---

## 3. No Role Restrictions

```js
const { protect } = require('../middleware/auth');
// No authorize() used anywhere
```

Unlike channels (admin-only) or assignments (faculty-only), projects have **no role restrictions**. Any authenticated user can create, update, and delete projects.

**Security is enforced inside the controller** — `getProject` checks that `req.user.id` is a member of the project before returning data. `deleteProject` checks if the requester is the owner.

---

## 4. `PATCH` — Partial Updates

```js
router.patch('/:id/progress',             protect, updateProgress);
router.patch('/:id/tasks/:taskId/status', protect, updateTaskStatus);
```

Both use `PATCH` instead of `PUT` because they update **single fields**:
- `updateProgress` — updates only `progress` (0.0 to 1.0 float)
- `updateTaskStatus` — updates only `status` (todo/in_progress/done)

Using `PATCH` communicates intent clearly: "I'm updating one specific field, not replacing the whole resource."

---

## 5. Nested Task Routes

```js
router.post('/:id/tasks',                  protect, createTask);
router.patch('/:id/tasks/:taskId/status', protect, updateTaskStatus);
```

Tasks are a **sub-resource** of projects. The URL structure `/projects/:id/tasks` reflects this ownership. `req.params.id` = project ID, `req.params.taskId` = task ID.

---

## 6. Frontend Connection (Flutter)

```dart
// ProjectsViewWidget — list projects
dio.get('/projects')

// Create project (CreateProjectDialog)
dio.post('/projects', data: { 'name': 'Graduation Project', 'description': '...' })

// ProjectDetailScreen — progress bar
dio.patch('/projects/$projectId/progress', data: { 'progress': 0.65 })

// Create task inside project
dio.post('/projects/$projectId/tasks', data: { 'title': 'Write report', 'status': 'todo' })
```

---

## 7. Final Summary

`projectRoutes.js` shows the nested sub-resource pattern (`/:id/tasks`) and consistent use of `PATCH` for partial updates. The absence of role-based middleware is intentional — projects are personal/team resources, not institutional ones. Authorization is enforced inside controllers via ownership checks.
