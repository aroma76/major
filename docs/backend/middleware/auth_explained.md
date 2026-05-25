# Word-by-Word Deep Dive: `backend/middleware/auth.js`

> This is the **authentication and authorization middleware** — the security guard of your API. It runs before protected routes and answers two questions: (1) "Are you logged in?" (`protect`), and (2) "Are you allowed to do this?" (`authorize`). Without this file, any person could access any data.

---

## Before Reading — Key Concepts

### What is JWT (JSON Web Token)?
When a user logs in successfully, the server creates a **JWT** — a digitally signed string that encodes the user's data:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwidXNlcm5hbWUiOiJhbGljZSJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```
The token has 3 parts separated by `.`:
- **Header** — algorithm used (`HS256`)
- **Payload** — the data (user id, role, name, email, expiry)
- **Signature** — a cryptographic signature using the `JWT_SECRET`

The signature makes tampering impossible — if anyone changes even one character of the payload, the signature won't match and the token is rejected.

The Flutter app stores this token after login and sends it in every request's `Authorization` header:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

### What is Middleware?
A middleware is a function that runs between receiving the request and sending the response. Each middleware can:
- Read and modify `req` and `res`
- End the request by sending a response (`res.json(...)`)
- Pass control to the next middleware by calling `next()`

---

## The Full File

```js
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const protect = async (req, res, next) => {
  let token;
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
    token = req.headers.authorization.split(' ')[1];
  }
  if (!token) return res.status(401).json({ success: false, message: 'Not authorized, no token' });
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if ('role' in decoded) {
      req.user = decoded;
    } else {
      const result = await pool.query(
        'SELECT id, name, email, role, programme_id, batch_year, current_semester, roll_number, avatar_initials, avatar_url FROM users WHERE id = $1',
        [decoded.id]
      );
      if (result.rows.length === 0) return res.status(401).json({ success: false, message: 'User not found' });
      req.user = result.rows[0];
    }
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Token invalid or expired' });
  }
};

const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role))
    return res.status(403).json({ success: false, message: `Role '${req.user.role}' is not authorized` });
  next();
};

module.exports = { protect, authorize };
```

---

## Line 1 — `const jwt = require('jsonwebtoken');`

**`jwt`** — the variable name we give to the imported module. Named `jwt` by convention.

**`require('jsonwebtoken')`** — loads the `jsonwebtoken` npm package
- This package provides functions to create (`jwt.sign`) and verify (`jwt.verify`) JWTs
- `jwt.sign(payload, secret, options)` — creates a token
- `jwt.verify(token, secret)` — verifies a token and returns the decoded payload

---

## Line 2 — `const pool = require('../config/db');`

Imported for the **legacy token fallback** (lines 18–23). Old tokens that don't have `role` embedded need a DB lookup.

---

## Lines 4–29 — `const protect = async (req, res, next) => {...}`

### `const protect`
- A constant named `protect`
- This is the function registered as middleware in routes: `router.get('/', protect, handler)`

### `async`
- Marks the function as asynchronous — needed because the legacy token path does `await pool.query(...)`

### `(req, res, next)`
- Three parameters — the standard Express middleware signature
- `next` — a function. Calling `next()` passes control to the next middleware or route handler

---

### Lines 5–8 — Extracting the Token

```js
let token;
if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
  token = req.headers.authorization.split(' ')[1];
}
```

**`let token;`**
- Declares `token` with `let` (not `const`) — because it's assigned conditionally below
- Currently `undefined`

**`req.headers`** — all HTTP headers sent with the request
- Headers are key-value pairs sent before the body
- The Flutter app sends: `Authorization: Bearer eyJhbGci...`
- `req.headers.authorization` — the value of the Authorization header
- Note: Express lowercases all header names, so `Authorization` becomes `authorization`

**`req.headers.authorization && req.headers.authorization.startsWith('Bearer ')`**
- `&&` — logical AND. Both sides must be truthy.
- First condition: `req.headers.authorization` — checks the header exists (is not undefined/null)
- Second condition: `.startsWith('Bearer ')` — checks it follows the Bearer scheme
  - `startsWith(prefix)` — String method. Returns `true` if the string begins with `prefix`
  - The space after `'Bearer '` is intentional — `"Bearer TOKEN"` has a space between "Bearer" and the token
- Why both checks? Without the first, `.startsWith()` would crash on `undefined`. Short-circuit evaluation: if the first is false, JS doesn't evaluate the second.

**`req.headers.authorization.split(' ')[1]`**
- `.split(' ')` — splits the string at every space, returns an array
- `"Bearer eyJhbGci..."` → `['Bearer', 'eyJhbGci...']`
- `[1]` — gets index 1 (second element) — the token itself, stripping "Bearer "

---

### Line 9 — `if (!token) return res.status(401).json({...})`

**`!token`** — truthy check. `!undefined` = `true`. If no token was found in the header, this is true.

**`return`** — exits the function immediately. Nothing below runs.

**`res.status(401)`** — 401 Unauthorized. HTTP convention for "you must be logged in."

**`.json({ success: false, message: 'Not authorized, no token' })`** — error response body

---

### Lines 10–28 — Verifying the Token

```js
try {
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  ...
} catch (err) {
  return res.status(401).json({ success: false, message: 'Token invalid or expired' });
}
```

**`try {...} catch (err) {...}`**
- `jwt.verify()` **throws** an error if the token is invalid, expired, or tampered with
- `try` — attempt to run this code
- `catch (err)` — if ANYTHING in the `try` block throws, catch it here
- `err` — the error object thrown by `jwt.verify()`

**`jwt.verify(token, process.env.JWT_SECRET)`**
- Verifies two things:
  1. The token's signature (was it signed with our secret key? — prevents forgery)
  2. The token's expiry (`exp` claim in the payload — tokens expire after 7 days)
- If valid: returns the decoded **payload** object: `{ id: 1, role: 'student', name: 'Alice', email: '...', iat: ..., exp: ... }`
- If invalid/expired: throws a `JsonWebTokenError` or `TokenExpiredError`

**`process.env.JWT_SECRET`** — the secret key used when creating the token (in `authController.js`)
- Must be the same secret for signing and verifying
- Never hardcoded — stored in `.env` as `JWT_SECRET=some_long_random_string`

---

### Lines 15–23 — Smart Token Strategy

```js
if ('role' in decoded) {
  req.user = decoded;
} else {
  const result = await pool.query(
    'SELECT id, name, email, role, ... FROM users WHERE id = $1',
    [decoded.id]
  );
  if (result.rows.length === 0) return res.status(401).json({...});
  req.user = result.rows[0];
}
```

**`'role' in decoded`**
- `in` operator — checks if a property exists in an object
- `'role' in { id: 1, role: 'student', name: 'Alice' }` → `true`
- `'role' in { id: 1 }` → `false`

**Why this check?**
- **New tokens** (created after an update to `authController.js`) embed `role`, `name`, and `email` directly in the JWT payload — so no DB query is needed per request (fast!)
- **Legacy tokens** (old ones before the update) only have `id` in the payload — need a DB lookup to get the rest
- This `if/else` handles both cases gracefully

**`req.user = decoded`** — attaches the user data to the request object
- Now every controller that runs after `protect` can access `req.user.id`, `req.user.role`, `req.user.name`, etc.
- This is how the system knows who made the request, without querying the DB every time

**`next()`** — pass control to the next middleware or controller. This is CRITICAL — without calling `next()`, the request would hang forever with no response.

---

### The `catch` block

```js
} catch (err) {
  return res.status(401).json({ success: false, message: 'Token invalid or expired' });
}
```

**What causes errors here?**
- Token signature doesn't match (tampered token)
- Token has expired (`exp` timestamp in the past)
- Token is malformed (random string, not a JWT)
- `JWT_SECRET` changed on the server (all old tokens instantly invalid)

Always return `401` — the user must log in again to get a fresh token.

---

## Lines 31–35 — `const authorize = (...roles) => (req, res, next) => {...}`

This is a **function that returns a function** — also called a **higher-order function** or **middleware factory**.

```js
const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role))
    return res.status(403).json({ success: false, message: `Role '${req.user.role}' is not authorized` });
  next();
};
```

### `(...roles)`
- `...roles` — the **rest parameter** syntax
- Collects all arguments into an array named `roles`
- `authorize('admin', 'faculty')` → `roles = ['admin', 'faculty']`
- `authorize('admin')` → `roles = ['admin']`
- The `...` here is NOT the spread operator (that spreads an array out), it's the rest parameter (that collects args into an array)

### `=> (req, res, next) => {...}`
- The outer arrow function takes `roles` and RETURNS another arrow function
- The returned function is the actual middleware (has `req, res, next`)
- Usage in routes: `authorize('admin', 'faculty')` — calling this evaluates the outer function and returns the inner middleware, which Express then registers

**Why this pattern?** — Middleware functions can only take `(req, res, next)`. But we need to parameterize the roles. The factory pattern solves this: call `authorize('admin')` to get a middleware that checks for 'admin'.

### `!roles.includes(req.user.role)`
- `roles` — the array of allowed roles, e.g. `['admin', 'faculty']`
- `.includes(value)` — Array method. Returns `true` if the array contains that value.
- `req.user.role` — the logged-in user's role (set by `protect` middleware earlier in the chain)
- `!` — NOT. So: "if the user's role is NOT in the allowed list"

### `res.status(403)`
- `403 Forbidden` — different from 401!
  - **401 Unauthorized**: "Who are you? Please log in." (not authenticated)
  - **403 Forbidden**: "I know who you are, but you're not allowed to do this." (authenticated but not authorized)

### `` `Role '${req.user.role}' is not authorized` ``
- Template literal with `${}` interpolation
- If `req.user.role = 'student'`, this produces: `"Role 'student' is not authorized"`

---

## Line 37 — `module.exports = { protect, authorize };`

**`{ protect, authorize }`** — exports both as named properties
- Shorthand for `{ protect: protect, authorize: authorize }`
- Routes import them with: `const { protect, authorize } = require('../middleware/auth');`

---

## How It Works in a Route Chain

```
router.post('/', protect, authorize('admin', 'faculty'), createAnnouncement);
```

When `POST /api/channels/7/announcements` comes in:

```
Step 1: protect(req, res, next)
  → Read Authorization header
  → Extract and verify JWT token
  → Set req.user = { id: 3, role: 'faculty', name: 'Dr. Smith', ... }
  → call next()

Step 2: authorize('admin', 'faculty')(req, res, next)
  → Check: does ['admin', 'faculty'].includes(req.user.role)?
  → req.user.role = 'faculty' → yes, it's in the list
  → call next()

Step 3: createAnnouncement(req, res)
  → req.user.id is available (set in step 1)
  → Inserts announcement into DB
  → Sends 201 response
```

If a **student** makes this request:
```
Step 1: protect → sets req.user = { id: 5, role: 'student', ... } → next()
Step 2: authorize → ['admin','faculty'].includes('student') = false → 403 Forbidden (stops here)
Step 3: Never reached
```

---

## Summary Table

| Function | Purpose | Key Logic |
|---|---|---|
| `protect` | Verify login (authentication) | Reads JWT from header, verifies signature, attaches user to req |
| `authorize(...roles)` | Check permissions (authorization) | Factory function — returns middleware that checks req.user.role |

| HTTP Code | Meaning | When used |
|---|---|---|
| 401 Unauthorized | Not logged in | No token, invalid token, expired token |
| 403 Forbidden | Logged in but wrong role | Student tries to create announcement |
