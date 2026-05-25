# 📄 `routes/assignmentRoutes.js` — Complete Explanation

**File Path:** `backend/routes/assignmentRoutes.js`
**Lines:** 21
**Mounted at:** `app.use('/api/channels/:id/assignments', assignmentRoutes)`
**Role:** CRUD for assignments per channel + student submission + faculty grading.

---

## 1. File Purpose

`assignmentRoutes.js` is the most route-rich file in the project. It covers the full assignment lifecycle: create → view → submit → grade. It uses controllers from two different files (`assignmentController` and `submissionController`).

---

## 2. Full Source Code

```js
const express = require('express');
const router = express.Router({ mergeParams: true }); // inherits :id (channelId) from parent

const {
  getAssignments, getAssignment, createAssignment,
  updateAssignment, updateAssignmentStatus, deleteAssignment, getSubmissions
} = require('../controllers/assignmentController');

const { submitAssignment, gradeSubmission, getMySubmission }
  = require('../controllers/submissionController');

const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/',                                  protect,                              getAssignments);
router.post('/',                                 protect, authorize('admin','faculty'), createAssignment);
router.get('/:assignId',                         protect,                              getAssignment);
router.put('/:assignId',                         protect, authorize('admin','faculty'), updateAssignment);
router.patch('/:assignId/status',               protect,                              updateAssignmentStatus);
router.delete('/:assignId',                      protect, authorize('admin','faculty'), deleteAssignment);
router.post('/:assignId/submit',                 protect, authorize('student'),        upload.single('file'), submitAssignment);
router.get('/:assignId/submissions',             protect, authorize('admin','faculty'), getSubmissions);
router.get('/:assignId/my-submission',           protect, authorize('student'),        getMySubmission);
router.put('/submissions/:subId/grade',          protect, authorize('admin','faculty'), gradeSubmission);
```

---

## 3. Route Table

| Method | Path | Who Can Access | Purpose |
|---|---|---|---|
| `GET` | `/api/channels/:id/assignments` | All authenticated | List all assignments for a channel |
| `POST` | `/api/channels/:id/assignments` | Admin, Faculty | Create new assignment |
| `GET` | `/api/channels/:id/assignments/:assignId` | All authenticated | Get single assignment detail |
| `PUT` | `/api/channels/:id/assignments/:assignId` | Admin, Faculty | Update assignment |
| `PATCH` | `/api/channels/:id/assignments/:assignId/status` | All authenticated | Update assignment status (Kanban drag) |
| `DELETE` | `/api/channels/:id/assignments/:assignId` | Admin, Faculty | Delete assignment |
| `POST` | `/api/channels/:id/assignments/:assignId/submit` | Student only | Submit assignment file |
| `GET` | `/api/channels/:id/assignments/:assignId/submissions` | Admin, Faculty | View all student submissions |
| `GET` | `/api/channels/:id/assignments/:assignId/my-submission` | Student only | View own submission status |
| `PUT` | `/api/channels/:id/assignments/submissions/:subId/grade` | Admin, Faculty | Grade a submission |

---

## 4. Role Separation — Faculty vs. Student

```
Faculty/Admin can:
  POST   /assignments        → Create
  PUT    /assignments/:id    → Update
  DELETE /assignments/:id    → Delete
  GET    /submissions        → See all students' work
  PUT    /submissions/:id/grade → Grade

Student can:
  POST   /:id/submit         → Submit their own file
  GET    /:id/my-submission  → Check their own submission status

Both can:
  GET    /assignments         → List assignments
  GET    /assignments/:id     → View assignment details
  PATCH  /:id/status         → Update Kanban status
```

---

## 5. Two Imports from Two Controllers

```js
const { getAssignments, ... } = require('../controllers/assignmentController');
const { submitAssignment, gradeSubmission, getMySubmission } = require('../controllers/submissionController');
```

Assignment CRUD lives in `assignmentController.js`. Submission-specific operations (submit, grade, view own) live in `submissionController.js`. They're separated because submissions have their own database table and business logic.

---

## 6. `PATCH` vs `PUT` — Semantic Difference

```js
router.put('/:assignId', ...)           // Full update — replace entire assignment
router.patch('/:assignId/status', ...)  // Partial update — only the status field
```

`PATCH /status` is used by the Kanban drag-and-drop in `AssignmentsViewWidget`. When a student drags an assignment from "To Do" to "In Progress", only the `status` field changes — a `PATCH` is semantically correct.

---

## 7. Student Submit — Upload BEFORE Controller

```js
router.post('/:assignId/submit',
  protect,
  authorize('student'),
  upload.single('file'),   // ← upload happens BEFORE submitAssignment
  submitAssignment
);
```

The correct order here is critical:
1. `protect` — Check authentication
2. `authorize('student')` — Check role
3. `upload.single('file')` — Upload file to Supabase, set `req.file`
4. `submitAssignment` — Reads `req.file.path` to store the submission URL

If `submitAssignment` ran before `upload.single('file')`, `req.file` would be `undefined`.

---

## 8. Grade Route — Unusual Path Structure

```js
router.put('/submissions/:subId/grade', protect, authorize('admin', 'faculty'), gradeSubmission);
```

This path starts with `/submissions/` — which is technically at the same nesting level as `/:assignId`. Express matches routes in order, so this **must be defined after** any specific `/:assignId` routes to avoid collision.

The full URL: `PUT /api/channels/5/assignments/submissions/12/grade`

---

## 9. Frontend Connection (Flutter)

```dart
// Get all assignments for a channel (used in AssignmentsViewWidget)
dio.get('/channels/$channelId/assignments')

// Create assignment (TeacherCreateAssignmentDialog)
dio.post('/channels/$channelId/assignments', data: {
  'title': 'Lab 3',
  'description': '...',
  'due_date': '2025-06-01T00:00:00.000Z',
  'max_marks': 100,
  'priority': 'high',
})

// Update Kanban status (drag-drop)
dio.patch('/channels/$channelId/assignments/$assignId/status', data: { 'status': 'in_progress' })

// Submit assignment (student)
dio.post('/channels/$channelId/assignments/$assignId/submit', data: FormData({
  'file': MultipartFile.fromBytes(bytes, filename: 'submission.pdf'),
}))
```

---

## 10. Final Summary

`assignmentRoutes.js` demonstrates the full CRUD + sub-resource pattern. The dual-controller import (assignment vs. submission), role-specific routes (`authorize('student')` vs. `authorize('admin','faculty')`), correct `upload.single` ordering before the controller, and the `PATCH /status` vs `PUT` distinction make this the richest route file in the project.
