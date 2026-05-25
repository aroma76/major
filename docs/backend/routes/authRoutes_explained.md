# Word-by-Word Deep Dive: `backend/routes/authRoutes.js`

> This file defines all the authentication-related URL routes. It controls who can register, who can log in, how profile updates work, and applies rate limiting to prevent brute-force attacks.

---

## The Full File

```js
const express    = require('express');
const rateLimit  = require('express-rate-limit');
const router     = express.Router();
const { register, login, getMe, updateProfile, changePassword } = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const upload     = require('../middleware/upload');

const loginLimiter = rateLimit({
  windowMs      : 15 * 60 * 1000,
  max           : 10,
  message       : { success: false, message: 'Too many login attempts. Try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders  : false,
});

router.post('/register', register);
router.post('/login', loginLimiter, login);
router.get('/me',              protect, getMe);
router.put('/profile',         protect, upload.single('avatar'), updateProfile);
router.post('/change-password', protect, changePassword);

module.exports = router;
```

---

## Line 1 — `const express = require('express');`

Imports the Express framework. Needed to call `express.Router()`.

---

## Line 2 — `const rateLimit = require('express-rate-limit');`

**`rateLimit`** — imports the `express-rate-limit` package

**`express-rate-limit`** — a middleware that limits how many requests a single IP address can make in a time window. Used here to prevent **brute-force attacks** on the login endpoint.

A brute-force attack: a bot tries thousands of password combinations per second until it guesses correctly. Rate limiting stops this by blocking IPs after too many attempts.

---

## Line 3 — `const router = express.Router();`

**`express.Router()`** — creates a mini-router for auth routes
- No `{ mergeParams: true }` here — unlike `announcementRoutes`, auth routes are top-level (`/api/auth/...`) and don't need params from a parent router

---

## Line 4 — Importing Auth Controller Functions

```js
const { register, login, getMe, updateProfile, changePassword } = require('../controllers/authController');
```

Pulls all 5 functions from the auth controller (all are exported from `authController.js`).

---

## Line 5 — `const { protect } = require('../middleware/auth');`

Only imports `protect` (not `authorize`) — auth routes don't need role-based access control, just login verification.

---

## Line 6 — `const upload = require('../middleware/upload');`

**`upload`** — a configured `multer` middleware instance from `upload.js`
- `multer` handles `multipart/form-data` requests (the format used to upload files)
- Used on the profile update route to handle avatar image uploads

---

## Lines 8–15 — `const loginLimiter = rateLimit({...})`

```js
const loginLimiter = rateLimit({
  windowMs      : 15 * 60 * 1000,
  max           : 10,
  message       : { success: false, message: 'Too many login attempts. Try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders  : false,
});
```

**`rateLimit({...})`** — creates a rate-limiting middleware. The `{...}` is the configuration object.

### `windowMs: 15 * 60 * 1000`

**`windowMs`** — the time window in milliseconds

**`15 * 60 * 1000`** — JavaScript evaluates this arithmetic at runtime:
- `60` — seconds in a minute
- `15 * 60 = 900` — seconds in 15 minutes
- `900 * 1000 = 900000` — milliseconds in 15 minutes
- Writing it as `15 * 60 * 1000` is intentional — far more readable than `900000`. The comment in your head: "15 minutes × 60 seconds × 1000ms"

### `max: 10`

**`max`** — maximum number of requests from one IP address in the `windowMs` window

**`10`** — 10 login attempts per IP per 15 minutes
- After the 10th attempt: all further requests get the `message` response with HTTP 429 (Too Many Requests)
- The counter resets after 15 minutes

### `message: { success: false, message: '...' }`

**`message`** — the response body sent when the limit is exceeded
- Written as an object to match the app's standard API response format
- `express-rate-limit` by default sends a plain string — but we override it with our JSON format

### `standardHeaders: true`

Adds `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` headers to the response. These let the Flutter app know how many attempts are left and when the window resets.

### `legacyHeaders: false`

Disables the older `X-RateLimit-*` headers (deprecated). Only the modern `RateLimit-*` headers are sent.

---

## Line 17 — `router.post('/register', register);`

**`router.post`** — handles `POST` requests on this router

**`'/register'`** — the path relative to where this router is mounted (`/api/auth`)
- Full URL: `POST /api/auth/register`

**`register`** — the controller function. No middleware before it:
- Registration doesn't need `protect` (you're not logged in yet)
- No rate limiter on register — attackers can't gain anything from registering rapidly (accounts need valid roll numbers)

---

## Line 18 — `router.post('/login', loginLimiter, login);`

**`'/login'`** — full URL: `POST /api/auth/login`

**`loginLimiter`** — the rate limiter runs BEFORE `login`
- This is the key protection: if a single IP tries 11+ times in 15 minutes, `loginLimiter` intercepts and returns 429 — `login` never runs

**`login`** — runs only if the rate limiter allows it (under 10 attempts)

---

## Line 19 — `router.get('/me', protect, getMe);`

**`router.get`** — handles `GET` requests

**`'/me'`** — full URL: `GET /api/auth/me`

**`protect`** — must be logged in. Verifies the JWT and attaches `req.user`.

**`getMe`** — simply returns `req.user` (set by `protect`). One-liner in the controller:
```js
const getMe = async (req, res) => res.json({ success: true, user: req.user });
```

---

## Line 20 — `router.put('/profile', protect, upload.single('avatar'), updateProfile);`

**`router.put`** — handles `PUT` requests. `PUT` is for full or partial **updates** (convention).

**`'/profile'`** — full URL: `PUT /api/auth/profile`

**`protect`** — verify login first

**`upload.single('avatar')`** — Multer middleware
- `upload` — the multer instance from `upload.js`
- `.single('avatar')` — expect ONE file with the field name `'avatar'` in the multipart form data
- After this middleware runs, `req.file` contains the uploaded file's buffer, mimetype, originalname, etc.
- `req.file` is `undefined` if no avatar was sent (profile update without changing avatar)

**`updateProfile`** — runs last, with access to both `req.body` (text fields) and `req.file` (optional avatar)

---

## Line 21 — `router.post('/change-password', protect, changePassword);`

**`router.post`** — `POST` method
- Could arguably be `PUT` or `PATCH`, but `POST` is used to match how the Flutter frontend calls it (comment in code: "POST: matches frontend call")

**`'/change-password'`** — full URL: `POST /api/auth/change-password`

**`protect`** — must be logged in to change your password

**`changePassword`** — verifies current password, validates new password strength, hashes and saves

---

## Line 23 — `module.exports = router;`

Exports the router. In `server.js`:
```js
const authRoutes = require('./routes/authRoutes');
app.use('/api/auth', authRoutes);
```
Every route in this file is prefixed with `/api/auth/`.

---

## Complete Route Table

| Method | Full URL | Middleware | Controller | Who Can Call |
|---|---|---|---|---|
| POST | `/api/auth/register` | none | `register` | Anyone |
| POST | `/api/auth/login` | `loginLimiter` (10/15min) | `login` | Anyone (rate limited) |
| GET | `/api/auth/me` | `protect` | `getMe` | Logged-in users |
| PUT | `/api/auth/profile` | `protect`, `upload.single('avatar')` | `updateProfile` | Logged-in users |
| POST | `/api/auth/change-password` | `protect` | `changePassword` | Logged-in users |
