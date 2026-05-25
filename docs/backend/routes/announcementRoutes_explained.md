# Word-by-Word Deep Dive: `backend/routes/announcementRoutes.js`

> This file defines the **URL routes** for announcements. It maps HTTP method + URL path combinations to the correct controller functions, and applies the right authentication/authorization middleware. Think of it as the traffic director — every announcement-related request passes through here first.

---

## Before Reading — What is a Router?

Express has a concept called a **Router** — a mini-application that only handles routes for a specific part of your API. Instead of defining every route in `server.js` (which would be enormous), you create separate router files and mount them:

```js
// In server.js:
app.use('/api/channels/:id/announcements', announcementRoutes);
```

Now every request to `/api/channels/.../announcements/...` goes to this router first.

---

## The Full File

```js
const express = require('express');
const router = express.Router({ mergeParams: true });
const { getAnnouncements, createAnnouncement, deleteAnnouncement } = require('../controllers/announcementController');
const { protect, authorize } = require('../middleware/auth');

router.get('/', protect, getAnnouncements);
router.post('/', protect, authorize('admin', 'faculty'), createAnnouncement);
router.delete('/:announcementId', protect, authorize('admin', 'faculty'), deleteAnnouncement);

module.exports = router;
```

---

## Line 1 — `const express = require('express');`

**`const express`** — import the Express framework

**`require('express')`** — loads Express from `node_modules/`. Express is the web framework that handles HTTP servers, routing, and middleware in Node.js.

---

## Line 2 — `const router = express.Router({ mergeParams: true });`

**`express.Router()`** — creates a new router instance. This is a mini Express app that can define routes, use middleware, etc.

**`{ mergeParams: true }`** — the options object passed to Router. This single option is critically important:

**`mergeParams: true`**
- By default, a child router does NOT have access to URL params from its parent
- In `server.js`, this router is mounted at: `app.use('/api/channels/:id/announcements', announcementRoutes)`
- The `:id` in `/api/channels/:id` is a parent URL parameter
- Without `mergeParams: true`: inside this router, `req.params.id` would be `undefined`
- With `mergeParams: true`: `req.params.id` is available — it contains the channel ID from the parent URL
- Without this option, `getAnnouncements` and `createAnnouncement` would fail trying to access `req.params.id`

---

## Line 3 — Importing Controller Functions

```js
const { getAnnouncements, createAnnouncement, deleteAnnouncement } = require('../controllers/announcementController');
```

**`{ getAnnouncements, createAnnouncement, deleteAnnouncement }`**
- Destructuring — pulls three named functions from the module's export object
- `announcementController.js` exports: `module.exports = { getAnnouncements, createAnnouncement, deleteAnnouncement }`

**`require('../controllers/announcementController')`**
- `..` — go up one folder (from `routes/` to `backend/`)
- `/controllers/announcementController` — then into that file

---

## Line 4 — Importing Auth Middleware

```js
const { protect, authorize } = require('../middleware/auth');
```

**`protect`** — a middleware function that:
1. Reads the `Authorization: Bearer <token>` header
2. Verifies the JWT token
3. Attaches the logged-in user to `req.user`
4. Calls `next()` if valid, or sends 401 if not

**`authorize`** — a **middleware factory** function. It takes roles as arguments and returns a middleware:
- `authorize('admin', 'faculty')` — returns a middleware that checks `req.user.role` is either 'admin' or 'faculty'
- If the role doesn't match → sends 403 Forbidden
- If it matches → calls `next()`, allowing the request to continue

---

## Line 6 — `router.get('/', protect, getAnnouncements);`

**`router.get`** — registers a GET request handler on this router

**`'/'`** — the path **relative to where this router is mounted**
- Router is mounted at `/api/channels/:id/announcements`
- `'/'` = the base of that — so the full URL is `GET /api/channels/:id/announcements`

**`protect`** — middleware argument. Express calls this BEFORE `getAnnouncements`
- Verifies the JWT. If invalid → sends 401 and stops. If valid → calls `next()` → `getAnnouncements` runs.

**`getAnnouncements`** — the actual handler function. Runs only if `protect` passed.

**The middleware chain:**
```
Request → protect() → (if valid) → getAnnouncements() → response
                     → (if invalid) → 401 Unauthorized (stops here)
```

**Why does every route need `protect`?** — Even reading announcements requires being logged in. Anonymous users (unauthenticated) should not be able to access any channel data.

---

## Line 7 — `router.post('/', protect, authorize('admin', 'faculty'), createAnnouncement);`

**`router.post`** — registers a POST request handler

**`'/'`** — same path as GET, but POST method → `POST /api/channels/:id/announcements`

**`protect`** — first: verify the JWT, attach `req.user`

**`authorize('admin', 'faculty')`** — second: check the role
- `authorize` is called HERE with the allowed roles as arguments
- It RETURNS a middleware function (a function that returns a function — called a **higher-order function** or **factory**)
- That returned middleware checks `req.user.role` against `['admin', 'faculty']`
- Students (`req.user.role === 'student'`) would get 403 Forbidden
- Only faculty and admins can create announcements

**`createAnnouncement`** — third: runs only if both middlewares passed

**Full chain:**
```
POST request
  → protect() — valid JWT? → yes, sets req.user
  → authorize('admin','faculty') — role check? → yes if faculty/admin
  → createAnnouncement() — inserts to DB, emits socket event, sends 201
```

---

## Line 8 — `router.delete('/:announcementId', protect, authorize('admin', 'faculty'), deleteAnnouncement);`

**`router.delete`** — registers a DELETE request handler

**`'/:announcementId'`** — path with a URL parameter
- `:announcementId` is a **route parameter** — a named placeholder for a dynamic value
- For URL `DELETE /api/channels/7/announcements/42`:
  - `req.params.id = '7'` (from parent, available due to `mergeParams: true`)
  - `req.params.announcementId = '42'` (from this route)
- The full URL becomes: `DELETE /api/channels/:id/announcements/:announcementId`

**`protect, authorize('admin', 'faculty')`** — same two middlewares as POST. Only faculty/admin can delete announcements.

**`deleteAnnouncement`** — runs the DELETE SQL and sends the response.

---

## Line 10 — `module.exports = router;`

**`module.exports = router`** — exports the router object (not wrapped in `{}` because there's only one thing to export)

In `server.js`:
```js
const announcementRoutes = require('./routes/announcementRoutes');
app.use('/api/channels/:id/announcements', announcementRoutes);
```

When Express sees a request to `/api/channels/7/announcements`, it hands it to this router, which matches the method and sub-path to the right handler.

---

## Complete URL Table

| Method | Full URL | Middleware | Handler |
|---|---|---|---|
| GET | `/api/channels/:id/announcements` | `protect` | `getAnnouncements` |
| POST | `/api/channels/:id/announcements` | `protect`, `authorize('admin','faculty')` | `createAnnouncement` |
| DELETE | `/api/channels/:id/announcements/:announcementId` | `protect`, `authorize('admin','faculty')` | `deleteAnnouncement` |

---

## Why Separate Files for Routes and Controllers?

**Single Responsibility Principle** — each file has one job:
- **Routes file**: decides WHICH URL goes WHERE, and WHAT middleware runs
- **Controller file**: decides WHAT HAPPENS (DB queries, business logic, responses)

If you need to add rate limiting to POST only, you add it to the routes file without touching the controller. If you need to change how announcements are created, you change the controller without touching the routes. Clean separation.
