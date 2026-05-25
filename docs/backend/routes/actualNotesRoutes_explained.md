# 📄 `routes/actualNotesRoutes.js` — Complete Explanation

**File Path:** `backend/routes/actualNotesRoutes.js`
**Lines:** 14
**Mounted at:** `app.use('/api/channels/:id/notes', actualNotesRoutes)`
**Role:** Backend notes CRUD (lecture notes) per channel — distinct from the frontend "saved files" feature.

---

## 1. Full Source Code

```js
const express = require('express');
const router = express.Router({ mergeParams: true }); // inherits :id (channelId)
const { protect } = require('../middleware/auth');
const { getNotes, createNote, deleteNote } = require('../controllers/notesController');

router.route('/')
  .get(protect, getNotes)
  .post(protect, createNote);

router.route('/:noteId')
  .delete(protect, deleteNote);
```

---

## 2. Route Table

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/channels/:id/notes` | List notes for a channel |
| `POST` | `/api/channels/:id/notes` | Create a note (text-based) for a channel |
| `DELETE` | `/api/channels/:id/notes/:noteId` | Delete a specific note |

---

## 3. `router.route()` — Method Chaining

```js
router.route('/')
  .get(protect, getNotes)
  .post(protect, createNote);
```

This is Express's built-in route chaining. It's equivalent to:
```js
router.get('/', protect, getNotes);
router.post('/', protect, createNote);
```

Advantage: No repetition of the path string `'/'`. Cleaner when multiple methods share the same path. Used here as a stylistic alternative to separate route declarations.

---

## 4. `mergeParams: true`

Needed to access `req.params.id` (channelId) from the parent mount `'/api/channels/:id/notes'`. The `getNotes` and `createNote` controllers need the channel ID to scope notes to the correct subject.

---

## 5. No Role Restriction

```js
router.route('/').get(protect, getNotes).post(protect, createNote);
```

No `authorize()` — any authenticated user can create and delete notes. In real academic systems, only teachers would add official lecture notes, but the current implementation treats notes as personal/shared annotations.

---

## 6. ⚠️ Different from Frontend "Saved Files"

**Important distinction:**
- **Backend notes** (`/api/channels/:id/notes`) — Database-backed text notes stored per channel
- **Frontend saved files** (`savedFilesProvider`) — In-memory files "saved" from chat messages (PDFs, images, etc.)

The `NotesViewWidget` in the frontend uses the **saved files** system (from `savedFilesProvider`), **not** this backend API. This backend notes API exists but is currently **unused** by the Flutter frontend. It was likely an earlier design that was superseded by the file-saving approach.

---

## 7. Frontend Connection (Flutter)

This API is **not currently called** by any provider in the frontend. The `NotesViewWidget` uses `savedFilesProvider` (in-memory file saves from chat). This route exists for future use or for a different client.

---

## 8. Final Summary

`actualNotesRoutes.js` uses Express's `router.route()` method chaining and `mergeParams: true`. Critically, this backend API is **not wired** to the current Flutter frontend — the notes feature was reimplemented client-side using `savedFilesProvider`. This route is dormant production code.
