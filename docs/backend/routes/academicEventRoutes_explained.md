# 📄 `routes/academicEventRoutes.js` — Complete Explanation

**File Path:** `backend/routes/academicEventRoutes.js`
**Lines:** 12
**Mounted at:** `app.use('/api/academic-events', academicEventRoutes)`
**Role:** Academic calendar event CRUD — holidays, exams, institutional dates shown in the Calendar view.

---

## 1. Full Source Code

```js
const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { getAcademicEvents, createAcademicEvent, updateAcademicEvent, deleteAcademicEvent }
  = require('../controllers/academicEventController');

router.get('/',     protect, getAcademicEvents);
router.post('/',    protect, createAcademicEvent);        // admin/teacher only in production
router.patch('/:id',protect, updateAcademicEvent);
router.delete('/:id',protect,deleteAcademicEvent);
```

---

## 2. Route Table

| Method | Path | Access | Purpose |
|---|---|---|---|
| `GET` | `/api/academic-events` | All authenticated | List all academic events (for calendar) |
| `POST` | `/api/academic-events` | All authenticated ⚠️ | Create a calendar event |
| `PATCH` | `/api/academic-events/:id` | All authenticated ⚠️ | Update an event |
| `DELETE` | `/api/academic-events/:id` | All authenticated ⚠️ | Delete an event |

---

## 3. ⚠️ Known Security Gap

```js
router.post('/',    protect, createAcademicEvent);  // comment: "admin/teacher only in production"
router.patch('/:id',protect, updateAcademicEvent);
router.delete('/:id',protect, deleteAcademicEvent);
```

The comment in the source code acknowledges this: `// admin/teacher only in production`. Currently, any authenticated user (including students) can create, update, and delete academic events.

**Fix needed:**
```js
router.post('/',    protect, authorize('admin', 'faculty'), createAcademicEvent);
router.patch('/:id',protect, authorize('admin', 'faculty'), updateAcademicEvent);
router.delete('/:id',protect, authorize('admin', 'faculty'), deleteAcademicEvent);
```

This is an unimplemented TODO in the codebase.

---

## 4. `PATCH` for Updates

```js
router.patch('/:id', protect, updateAcademicEvent);
```

`PATCH` is appropriate here — academic events have multiple fields (title, date, type, color), and the update endpoint supports changing individual fields without replacing the whole object.

---

## 5. Frontend Connection (Flutter)

```dart
// CalendarViewWidget — loads events for the calendar
// Provider: calendarEventsProvider
dio.get('/academic-events')

// Create event (currently only admin-intended, but no enforcement)
dio.post('/academic-events', data: {
  'title': 'Mid Semester Exam',
  'date': '2025-10-15',
  'type': 'exam',
  'color': '#FF5733',
})
```

The `CalendarViewWidget` uses `TableCalendar` with events loaded from `calendarEventsProvider` which calls `GET /api/academic-events`.

---

## 6. Final Summary

`academicEventRoutes.js` is the only route file with a **known, documented security gap** — write operations lack role restrictions and the comment explicitly calls it out as a TODO for production. The calendar's read path is secure; it's the write path that needs `authorize('admin', 'faculty')` added.
