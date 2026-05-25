# 📄 `routes/enrollmentRoutes.js` — Complete Explanation

**File Path:** `backend/routes/enrollmentRoutes.js`
**Lines:** 12
**Mounted at:** `app.use('/api/enrollments', enrollmentRoutes)`
**Role:** Student enrollment management — view own enrollments, enroll/unenroll (faculty/admin), bulk enroll (admin only).

---

## 1. Full Source Code

```js
const express = require('express');
const router = express.Router();

const { enroll, unenroll, getMyEnrollments, bulkEnroll }
  = require('../controllers/enrollmentController');
const { protect, authorize } = require('../middleware/auth');

router.get('/my',   protect,                            getMyEnrollments);
router.post('/',    protect, authorize('admin','faculty'), enroll);
router.delete('/',  protect, authorize('admin','faculty'), unenroll);
router.post('/bulk',protect, authorize('admin'),         bulkEnroll);
```

---

## 2. Route Table

| Method | Path | Access | Purpose |
|---|---|---|---|
| `GET` | `/api/enrollments/my` | All authenticated | Get own channel enrollments |
| `POST` | `/api/enrollments` | Admin, Faculty | Enroll a student in a channel |
| `DELETE` | `/api/enrollments` | Admin, Faculty | Unenroll a student from a channel |
| `POST` | `/api/enrollments/bulk` | **Admin only** | Enroll multiple students at once |

---

## 3. Three-Tier Access Pattern

```js
router.get('/my',    protect,                            getMyEnrollments); // Any user
router.post('/',     protect, authorize('admin','faculty'), enroll);          // Faculty+
router.post('/bulk', protect, authorize('admin'),         bulkEnroll);       // Admin only
```

This shows a clear three-tier hierarchy:
- **Any user:** Read own enrollments
- **Faculty + Admin:** Enroll/unenroll individual students
- **Admin only:** Bulk enrollment (system-level operation)

Faculty CAN enroll students (e.g., a teacher adding a student to their class). But only admin can bulk-enroll (semester-wide operations that affect hundreds of students).

---

## 4. `DELETE /` — Body-Based Delete

```js
router.delete('/', protect, authorize('admin','faculty'), unenroll);
```

Unusual pattern — `DELETE` without an ID in the URL. The student ID and channel ID are passed in `req.body`:
```js
// Client sends:
{ "user_id": 42, "channel_id": 5 }
```

This is a deliberate choice: enrollment is identified by a *composite key* (`user_id` + `channel_id`), not a single integer ID. Putting both in the URL would require `/api/enrollments/:userId/:channelId` — which works but `req.body` is simpler.

---

## 5. `GET /my` — The Most-Called Enrollment Route

```js
router.get('/my', protect, getMyEnrollments);
```

This is the `channelsProvider` in Flutter — called every time the channels list is needed. It returns all channels the current user is enrolled in, including subject name, teacher name, semester number, and color.

---

## 6. Frontend Connection (Flutter)

```dart
// channelsProvider — enrolled subjects
dio.get('/enrollments/my')

// Admin enrolls a student (not implemented in current UI — admin panel)
dio.post('/enrollments', data: { 'user_id': 42, 'channel_id': 5 })

// Bulk enrollment (CSV upload — not in current Flutter frontend)
dio.post('/enrollments/bulk', data: { students: [...] })
```

---

## 7. Final Summary

`enrollmentRoutes.js` demonstrates three-tier role-based access and the body-based DELETE pattern for composite-key resources. The `/my` endpoint is the backbone of the channel display across the entire app — every widget that shows "your subjects" calls this route.
