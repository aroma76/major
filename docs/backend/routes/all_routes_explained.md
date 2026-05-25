# Word-by-Word Deep Dive: All Remaining Route Files

> This document covers all remaining route files: **messageRoutes**, **assignmentRoutes**, **subjectRoutes (channelRoutes)**, and the pattern they follow. After reading `announcementRoutes_explained.md` and `authRoutes_explained.md`, you already know the building blocks — this doc focuses on what's NEW in each file.

---

## `backend/routes/messageRoutes.js`

```js
const express = require('express');
const router = express.Router({ mergeParams: true });
const { getMessages, sendMessage, pinMessage, deleteMessage, getPinnedMessages } = require('../controllers/messageController');
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/', protect, getMessages);
router.post('/', protect, upload.single('file'), sendMessage);
router.get('/pinned', protect, getPinnedMessages);
router.put('/:msgId/pin', protect, authorize('admin', 'faculty'), pinMessage);
router.delete('/:msgId', protect, deleteMessage);

module.exports = router;
```

Mounted at: `app.use('/api/channels/:id/messages', messageRoutes)` — so all paths here are relative to that prefix.

### `router.post('/', protect, upload.single('file'), sendMessage)`

**Three middleware functions:**
1. `protect` — verify JWT, attach `req.user`
2. `upload.single('file')` — multer parses the multipart body. The file field must be named `'file'` in the multipart form. After this, `req.file` contains the uploaded file info (URL from Supabase).
3. `sendMessage` — the actual handler

**All users can send messages** — no `authorize()` restriction. Students and faculty alike can post.

### `router.get('/pinned', protect, getPinnedMessages)`

**Route order matters critically.** `/pinned` must be defined BEFORE `/:msgId`.

Why? If `/:msgId` came first, Express would match `/pinned` as `{ msgId: 'pinned' }` — treating "pinned" as an ID, not the `/pinned` route. **Always put literal paths before parameterized paths in Express.**

### `router.put('/:msgId/pin', protect, authorize('admin', 'faculty'), pinMessage)`

**`PUT` not `PATCH`** — convention choice (either works). Only faculty/admin can pin messages. Students cannot.

**`/:msgId`** — the message ID. Available as `req.params.msgId` in the controller.

### `router.delete('/:msgId', protect, deleteMessage)`

No `authorize()` — the controller itself handles authorization (sender can delete own, faculty/admin can delete any). This is a valid approach when the authorization logic is too nuanced for a simple role check.

### Complete URL Table for Messages

| Method | Full URL | Middleware | Handler |
|---|---|---|---|
| GET | `/api/channels/:id/messages` | `protect` | `getMessages` |
| POST | `/api/channels/:id/messages` | `protect`, `upload.single('file')` | `sendMessage` |
| GET | `/api/channels/:id/messages/pinned` | `protect` | `getPinnedMessages` |
| PUT | `/api/channels/:id/messages/:msgId/pin` | `protect`, `authorize('admin','faculty')` | `pinMessage` |
| DELETE | `/api/channels/:id/messages/:msgId` | `protect` | `deleteMessage` |

---

## `backend/routes/assignmentRoutes.js`

```js
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
router.patch('/:assignId/status', protect, updateAssignmentStatus);
router.delete('/:assignId', protect, authorize('admin', 'faculty'), deleteAssignment);
router.post('/:assignId/submit', protect, authorize('student'), upload.single('file'), submitAssignment);
router.get('/:assignId/submissions', protect, authorize('admin', 'faculty'), getSubmissions);
router.get('/:assignId/my-submission', protect, authorize('student'), getMySubmission);
router.put('/submissions/:subId/grade', protect, authorize('admin', 'faculty'), gradeSubmission);
```

### Two Controller Files in One Router

This router imports from BOTH `assignmentController` and `submissionController`. This is acceptable — the route file's job is to map URLs to handlers, regardless of which controller file they come from. The URLs are logically grouped under assignments (`/api/channels/:id/assignments/...`).

### `router.patch('/:assignId/status', protect, updateAssignmentStatus)`

**No `authorize()`** — both students AND faculty can change the Kanban status. The comment says this is for "Kanban drag-and-drop" — students can move their own assignment cards between todo/in-progress/done columns.

### `router.post('/:assignId/submit', protect, authorize('student'), upload.single('file'), submitAssignment)`

**`authorize('student')`** — ONLY students can submit. Faculty cannot submit to their own assignments.

**Four middleware in sequence:** protect → authorize('student') → upload.single('file') → submitAssignment

The upload middleware runs AFTER authorization — if the student is not authorized, multer never even processes the file upload (efficient rejection).

### `router.put('/submissions/:subId/grade', protect, authorize('admin', 'faculty'), gradeSubmission)`

**Important:** This route has a LITERAL first segment `/submissions/` — it will NOT match `/:assignId` because Express checks routes in order and matches the most specific. The `:assignId` routes all have IDs, not the literal "submissions".

But there's a potential conflict: `/submissions/:subId` could theoretically match `/:assignId` where `assignId = 'submissions'`. Express resolves this because literal segments (`submissions`) have priority over parameter segments (`:assignId`) in route matching.

### Complete URL Table for Assignments

| Method | Full URL | Access | Handler |
|---|---|---|---|
| GET | `/api/channels/:id/assignments` | All | `getAssignments` (different data per role) |
| POST | `/api/channels/:id/assignments` | Faculty/Admin | `createAssignment` |
| GET | `/api/channels/:id/assignments/:assignId` | All | `getAssignment` |
| PUT | `/api/channels/:id/assignments/:assignId` | Faculty/Admin | `updateAssignment` |
| PATCH | `/api/channels/:id/assignments/:assignId/status` | All | `updateAssignmentStatus` |
| DELETE | `/api/channels/:id/assignments/:assignId` | Faculty/Admin | `deleteAssignment` |
| POST | `/api/channels/:id/assignments/:assignId/submit` | Students only | `submitAssignment` |
| GET | `/api/channels/:id/assignments/:assignId/submissions` | Faculty/Admin | `getSubmissions` |
| GET | `/api/channels/:id/assignments/:assignId/my-submission` | Students only | `getMySubmission` |
| PUT | `/api/channels/:id/assignments/submissions/:subId/grade` | Faculty/Admin | `gradeSubmission` |

---

## `backend/routes/subjectRoutes.js` (mounted as channelRoutes)

```js
const express = require('express');
const router  = express.Router();
const { getChannels, getChannel, createChannel, updateChannel, deleteChannel, getChannelMembers } = require('../controllers/channelController');
const { protect, authorize } = require('../middleware/auth');

router.get  ('/',              protect,                     getChannels);
router.get  ('/:id',          protect,                     getChannel);
router.post ('/',              protect, authorize('admin'), createChannel);
router.put  ('/:id',          protect, authorize('admin'), updateChannel);
router.delete('/:id',         protect, authorize('admin'), deleteChannel);
router.get  ('/:id/members',  protect,                     getChannelMembers);

module.exports = router;
```

### No `mergeParams: true`

This router is mounted at `/api/channels` — it defines `:id` itself (it's not a parent param). Unlike announcement/message routes which inherit `:id` from the parent, this router IS the top-level route that creates `:id`.

### Vertical Alignment of Arguments

```js
router.get  ('/',    protect,                     getChannels);
router.post ('/',    protect, authorize('admin'), createChannel);
```

The spaces align the columns visually — `'/'`, `protect`, `authorize(...)`, and handler are all in consistent columns. This is a style choice for readability.

### Admin-Only Mutations

Only admin can create, update, or delete channels. Getting channels and members is open to all authenticated users (each role sees different data through the controller logic).

### Complete URL Table for Channels

| Method | Full URL | Access | Handler |
|---|---|---|---|
| GET | `/api/channels` | All | `getChannels` (role-filtered) |
| GET | `/api/channels/:id` | All | `getChannel` |
| POST | `/api/channels` | Admin only | `createChannel` |
| PUT | `/api/channels/:id` | Admin only | `updateChannel` |
| DELETE | `/api/channels/:id` | Admin only | `deleteChannel` |
| GET | `/api/channels/:id/members` | All | `getChannelMembers` |

---

## Other Route Files — Quick Reference

### `backend/routes/enrollmentRoutes.js`

```js
router.post('/',       protect, authorize('admin', 'faculty'), enroll);
router.delete('/',     protect, authorize('admin', 'faculty'), unenroll);
router.get('/me',      protect, getMyEnrollments);
router.post('/bulk',   protect, authorize('admin', 'faculty'), bulkEnroll);
```

- Enrollment management is admin/faculty only. Students use `GET /me` to see their own.
- `DELETE /` — unusual: DELETE with a body (`{ user_id, channel_id }`). Normally DELETE uses URL params, but this passes IDs in the body since it's a join table row.

### `backend/routes/notificationRoutes.js`

```js
router.get('/',               protect, getNotifications);
router.patch('/:id/read',     protect, markRead);
router.patch('/read-all',     protect, markAllRead);
router.delete('/:id',         protect, deleteNotification);
router.get('/unread-count',   protect, getUnreadCount);
```

**Route order:** `/read-all` is a literal and must come BEFORE `/:id/read` — otherwise Express would try to find a notification with `id = 'read-all'`.

### `backend/routes/projectRoutes.js`

```js
router.get('/',                     protect, getProjects);
router.post('/',                    protect, createProject);
router.get('/:id',                  protect, getProject);
router.patch('/:id/progress',       protect, updateProgress);
router.delete('/:id',               protect, deleteProject);
router.post('/:id/tasks',           protect, createTask);
router.patch('/:id/tasks/:taskId/status', protect, updateTaskStatus);
```

No role restrictions at the route level — all authenticated users can create projects. The authorization (creator-only for delete/progress) is handled inside the controller.

### `backend/routes/teacherRoutes.js`

```js
router.get('/stats',           protect, authorize('admin', 'faculty'), getTeacherStats);
router.get('/recent-activity', protect, authorize('admin', 'faculty'), getTeacherRecentActivity);
router.get('/student-activity',protect, getStudentRecentActivity);
```

Faculty/admin for teacher dashboard. All authenticated for student dashboard (students call `/student-activity`).

### `backend/routes/actualNotesRoutes.js`

```js
router.get('/',         protect, getNotes);
router.post('/',        protect, createNote);
router.delete('/:noteId', protect, deleteNote);
```

No `authorize()` — all enrolled users can read, write, and delete (with note-level ownership check in controller).

### `backend/routes/academicEventRoutes.js`

```js
router.get('/',       protect, getAcademicEvents);
router.post('/',      protect, authorize('admin', 'faculty'), createAcademicEvent);
router.put('/:id',    protect, authorize('admin', 'faculty'), updateAcademicEvent);
router.delete('/:id', protect, authorize('admin', 'faculty'), deleteAcademicEvent);
```

CRUD for academic calendar events. Only faculty/admin can manage, all can view.

---

## The Pattern Every Route File Follows

```js
// 1. Import Express
const express = require('express');

// 2. Create router (mergeParams: true if inheriting parent URL params like :id)
const router = express.Router({ mergeParams: true });

// 3. Import controller functions (and from multiple controllers if needed)
const { fn1, fn2 } = require('../controllers/someController');

// 4. Import middleware
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');  // only if file uploads

// 5. Define routes: method, path, middleware chain, handler
router.METHOD('path', protect, [authorize(...)], [upload.single(...)], handler);

// 6. Export
module.exports = router;
```

**Rule of thumb for middleware order:**
1. `protect` — always first (verify identity)
2. `authorize(...)` — second (check permissions) — saves DB calls if unauthorized
3. `upload.single(...)` — third (process file) — saves bandwidth if unauthorized
4. `handler` — always last (do the actual work)
