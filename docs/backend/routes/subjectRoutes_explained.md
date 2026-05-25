# 📄 `routes/subjectRoutes.js` (Channel Routes) — Complete Explanation

**File Path:** `backend/routes/subjectRoutes.js`
**Lines:** 17
**Mounted at:** `app.use('/api/channels', subjectRoutes)`
**Role:** CRUD for subject channels + member listing. Admin-only for write operations.

---

## 1. File Purpose

Despite being named `subjectRoutes.js`, this file controls **channels** (`/api/channels`). A "channel" in this project = a subject/class (e.g., "Data Structures — Sem 3"). The naming inconsistency (subject vs. channel) reflects an early design decision.

---

## 2. Full Source Code

```js
const express  = require('express');
const router   = express.Router();

const {
  getChannels, getChannel, createChannel, updateChannel, deleteChannel, getChannelMembers
} = require('../controllers/channelController');

const { protect, authorize } = require('../middleware/auth');

// All authenticated users see their enrolled channels
router.get  ('/',             protect,                       getChannels);
router.get  ('/:id',         protect,                       getChannel);
router.post ('/',             protect, authorize('admin'),   createChannel);
router.put  ('/:id',         protect, authorize('admin'),   updateChannel);
router.delete('/:id',        protect, authorize('admin'),   deleteChannel);
router.get  ('/:id/members', protect,                       getChannelMembers);
```

---

## 3. Route Table

| Method | Path | Access | Purpose |
|---|---|---|---|
| `GET` | `/api/channels` | All authenticated | List channels the current user is enrolled in |
| `GET` | `/api/channels/:id` | All authenticated | Get single channel details |
| `POST` | `/api/channels` | **Admin only** | Create a new subject channel |
| `PUT` | `/api/channels/:id` | **Admin only** | Update channel name/subject info |
| `DELETE` | `/api/channels/:id` | **Admin only** | Delete a channel and all its messages |
| `GET` | `/api/channels/:id/members` | All authenticated | List all enrolled students and teachers |

---

## 4. Admin-Only Write Operations

```js
router.post ('/', protect, authorize('admin'),  createChannel);
router.put  ('/:id', protect, authorize('admin'), updateChannel);
router.delete('/:id', protect, authorize('admin'), deleteChannel);
```

Only **admin** can create/modify/delete channels. Note: `authorize('admin')` — not `authorize('admin', 'faculty')`. Faculty cannot create new subjects/channels; that's an institutional decision managed by admins only.

**Contrast with `announcementRoutes.js`:**
```js
// Announcements: both faculty and admin can create
router.post('/', protect, authorize('admin', 'faculty'), createAnnouncement);

// Channels: only admin can create
router.post('/', protect, authorize('admin'), createChannel);
```

---

## 5. `GET /api/channels` — Returns Enrolled Only

The `getChannels` controller does NOT return all channels in the database. It queries:
```sql
SELECT c.* FROM channels c
INNER JOIN enrollments e ON e.channel_id = c.id
WHERE e.user_id = $1  -- req.user.id
```

A student sees only their enrolled subjects. A faculty member sees their assigned subjects. An admin sees all.

---

## 6. `GET /api/channels/:id/members` — Member Listing

```js
router.get('/:id/members', protect, getChannelMembers);
```

Returns all users enrolled in the channel. Used in the frontend for showing "who's in this class". No role restriction — any enrolled user can see fellow members.

---

## 7. No `mergeParams` Needed

```js
const router = express.Router(); // No mergeParams
```

Unlike `messageRoutes` and `assignmentRoutes`, this router is mounted at the top level (`/api/channels`), not nested inside another router. No parent params to inherit.

---

## 8. Frontend Connection (Flutter)

```dart
// channelsProvider — watches enrolled channels
dio.get('/channels')

// SubjectHubSheet header info
dio.get('/channels/$channelId')

// Channel members list
dio.get('/channels/$channelId/members')
```

---

## 9. Why "subjectRoutes" Not "channelRoutes"?

The file is named `subjectRoutes.js` but mounted at `/api/channels`. This suggests the original design intended a "subjects" concept (matching the UI — `SubjectsViewWidget`), but the database/API settled on "channels" (matching the Socket.IO channel concept). The name mismatch is harmless but a refactoring candidate.

---

## 10. Final Summary

`subjectRoutes.js` defines the 6 core channel endpoints. The key design decision is admin-only restriction on write operations (vs. faculty for announcements/assignments). The `getChannels` endpoint returns only the user's own enrolled channels — a server-side filter that prevents data leakage between unrelated classes.
