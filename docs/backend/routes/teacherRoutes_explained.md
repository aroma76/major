# 📄 `routes/teacherRoutes.js` — Complete Explanation

**File Path:** `backend/routes/teacherRoutes.js`
**Lines:** 11
**Mounted at:** `app.use('/api/dashboard', teacherRoutes)`
**Role:** Dashboard data endpoints — teacher stats, teacher recent activity, and student recent activity.

---

## 1. Full Source Code

```js
const express = require('express');
const router = express.Router();

const { getTeacherStats, getTeacherRecentActivity, getStudentRecentActivity }
  = require('../controllers/teacherController');
const { protect, authorize } = require('../middleware/auth');

router.get('/stats',            protect, authorize('faculty', 'admin'), getTeacherStats);
router.get('/recent-activity',  protect, authorize('faculty', 'admin'), getTeacherRecentActivity);
router.get('/student-activity', protect,                                getStudentRecentActivity);
```

---

## 2. Route Table

| Method | Path | Access | Purpose |
|---|---|---|---|
| `GET` | `/api/dashboard/stats` | Faculty, Admin | Teacher overview stats (students, assignments, submissions) |
| `GET` | `/api/dashboard/recent-activity` | Faculty, Admin | Teacher's recent feed (new submissions, etc.) |
| `GET` | `/api/dashboard/student-activity` | **All authenticated** | Student home dashboard feed (announcements, messages) |

---

## 3. Why `/student-activity` Has No Role Restriction

```js
router.get('/student-activity', protect, getStudentRecentActivity);  // No authorize()
```

`getStudentRecentActivity` is used by the **student** dashboard home (`Today Overview Widget`). It returns: recent announcements, new messages, upcoming assignments.

It's not restricted because:
- Students are the primary consumers
- Faculty/admin may also call it to see the student view
- The controller filters data by `req.user.id` (only shows content for the user's enrolled channels)

---

## 4. Teacher Stats vs. Student Activity — Same Route File, Different Roles

```
Faculty can:  GET /stats           → How many submissions? How many students?
Faculty can:  GET /recent-activity → What did students submit recently?
Student can:  GET /student-activity → What announcements/assignments are new?
```

All three are read-only (GET). No POST/PUT/DELETE — this is a read-only dashboard data API.

---

## 5. Frontend Connection (Flutter)

```dart
// teacherStatsProvider — TeacherOverviewWidget stats cards
dio.get('/dashboard/stats')

// Teacher recent activity panel
dio.get('/dashboard/recent-activity')

// dashboardRecentActivityProvider (student home dashboard)
dio.get('/dashboard/student-activity')
```

In the Flutter providers:
```dart
// api_providers.dart
final dashboardRecentActivityProvider = FutureProvider.family<..., bool>((ref, isFaculty) async {
  final endpoint = isFaculty ? '/dashboard/recent-activity' : '/dashboard/student-activity';
  return await ApiService().dio.get(endpoint);
});
```

---

## 6. Final Summary

`teacherRoutes.js` is simple (3 GET routes) but demonstrates mixed access: faculty-only for teacher data, open-to-all for student data. The file is named "teacherRoutes" but hosts student-facing endpoints too — a slight naming inconsistency that's a refactoring candidate.
