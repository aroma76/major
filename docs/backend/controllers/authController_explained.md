# Word-by-Word Deep Dive: `backend/controllers/authController.js`

> This is the **authentication controller** — it handles registration, login, profile management, and password changes. It's the gateway through which every user enters the system. Understanding this file deeply means understanding how security, password hashing, and JWT tokens work.

---

## Before Reading — Critical Concepts

### What is Password Hashing?
**Never store plain passwords.** If your database leaks, plain passwords expose all users immediately.

Instead, passwords are **hashed** — run through a one-way mathematical function that produces a fixed-length string. The same password always produces the same hash, but you cannot reverse the hash to get the original password.

```
"myPassword123" → bcrypt → "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy"
```

When a user logs in, you hash their entered password and compare hashes — never comparing plain text passwords.

### What is bcrypt?
`bcrypt` is a password hashing algorithm designed to be **intentionally slow**. Unlike MD5 or SHA-256 (which are fast — designed for checksums), bcrypt takes ~100ms per hash on purpose. This makes brute-forcing billions of passwords per second impossible — each one takes 100ms.

The **cost factor** (also called rounds or work factor) controls how slow it is:
- Cost 10 → ~100ms per hash (used here — OWASP recommendation)
- Cost 12 → ~400ms per hash (used in high-security apps)
- Cost 14 → ~1.6 seconds per hash (very high security)

### What is a JWT?
JWT (JSON Web Token) is a self-contained token that proves a user is who they say they are. Structure:
```
header.payload.signature
```
- **Header**: algorithm (`HS256` = HMAC with SHA-256)
- **Payload**: data you embed, e.g. `{ id: 1, role: 'student', exp: 1234567890 }`
- **Signature**: `HMAC-SHA256(base64(header) + "." + base64(payload), JWT_SECRET)`

The signature uses your `JWT_SECRET` — only your server knows this key, so only your server can create valid tokens. If anyone changes the payload, the signature won't match and the token is rejected.

---

## Line 1 — `const bcrypt = require('bcryptjs');`

**`bcrypt`** — the variable name. By convention named after the algorithm.

**`require('bcryptjs')`** — loads the `bcryptjs` package
- Note: `bcryptjs` (with `js`) is a pure-JavaScript implementation. The alternative `bcrypt` (without `js`) is a native C++ binding (faster but requires compilation). `bcryptjs` works everywhere without compilation issues.

Key functions used:
- `bcrypt.hash(password, costFactor)` — async. Takes plain text + cost, returns the hash string.
- `bcrypt.compare(plain, hash)` — async. Returns `true` if `plain` matches the hash, `false` otherwise.

---

## Line 2 — `const jwt = require('jsonwebtoken');`

**`jwt`** — the `jsonwebtoken` npm package

Key functions used:
- `jwt.sign(payload, secret, options)` — creates a JWT
- `jwt.verify(token, secret)` — verifies a JWT and returns the payload (throws if invalid)

---

## Lines 5–11 — `generateToken` helper function

```js
const generateToken = (user) =>
  jwt.sign(
    { id: user.id, role: user.role, name: user.name, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
```

**`const generateToken = (user) =>`**
- A constant holding an arrow function that takes a `user` object

**`jwt.sign(payload, secret, options)`** — creates and signs a JWT

**First argument — `{ id: user.id, role: user.role, name: user.name, email: user.email }`** — the **payload**:
- `id: user.id` — the user's database ID. Used in every query to identify who made the request.
- `role: user.role` — `'student'`, `'faculty'`, or `'admin'`. Used by `authorize()` middleware.
- `name: user.name` — embedded so middleware doesn't need a DB query to get the name.
- `email: user.email` — same reason as name.

**Why embed role, name, email in the token?** — The `protect` middleware runs on every single authenticated request. If it needed a DB query each time to get the user's role and name, that's N+1 queries for every API call. Embedding these in the token means zero DB queries per request (for modern tokens).

**Second argument — `process.env.JWT_SECRET`** — the signing key
- A long random string stored in `.env`
- Example: `JWT_SECRET=a8f3k2js9dkf...` (should be 32+ random characters)
- **Never expose this.** Anyone with this secret can forge any token.

**Third argument — `{ expiresIn: process.env.JWT_EXPIRES_IN || '7d' }`**
- `expiresIn` — how long the token is valid
- `process.env.JWT_EXPIRES_IN || '7d'` — use the env var if set, otherwise default to 7 days
- `'7d'` — the `jsonwebtoken` shorthand format: `'7d'` = 7 days, `'24h'` = 24 hours, `'60s'` = 60 seconds
- After expiry, `jwt.verify()` throws `TokenExpiredError` → user must log in again

---

## Lines 20–63 — `register` function

```js
const register = async (req, res) => {
  const { name, email, password, roll_number } = req.body;
  const role = 'student';
  ...
};
```

### `const { name, email, password, roll_number } = req.body;`
Destructures the 4 fields from the request body. The Flutter registration form sends these.

### `const role = 'student';`
**This is a security decision.** The role is HARDCODED to `'student'` — it is NOT read from `req.body`.

Why? Without this, a malicious user could send `{ role: 'admin' }` in the body and register as admin. By hardcoding, this attack is impossible. Faculty/admin accounts are promoted via a separate admin-only route.

### `if (!name || !email || !password)`
Guards against incomplete requests. Returns 400 immediately without touching the database.

### Password Strength Regex (Lines 30–32)

```js
const strongPassword = /^(?=.*[A-Za-z])(?=.*\d).{8,}$/;
if (!strongPassword.test(password))
  return res.status(400).json({...});
```

**`/^(?=.*[A-Za-z])(?=.*\d).{8,}$/`** — a **regular expression** (regex)

Breaking it down character by character:
- `/` — start of regex literal in JavaScript
- `^` — anchor: start of the string
- `(?=.*[A-Za-z])` — a **lookahead**: "at some point ahead, there must be at least one letter (upper or lowercase)"
  - `(?=` — positive lookahead start
  - `.*` — any character (`.`), zero or more times (`*`)
  - `[A-Za-z]` — a character class: any letter A-Z or a-z
  - `)` — end lookahead
- `(?=.*\d)` — another lookahead: "there must be at least one digit"
  - `\d` — regex shorthand for `[0-9]` (any digit)
- `.{8,}` — any character, at least 8 times
  - `.` — any character except newline
  - `{8,}` — 8 or more repetitions
- `$` — anchor: end of the string
- `/` — end of regex literal

**`.test(password)`** — String method on regex. Returns `true` if `password` matches the pattern, `false` otherwise.

**Result:** Password must be 8+ characters AND contain at least one letter AND at least one digit. `"password"` fails (no digit). `"12345678"` fails (no letter). `"pass1234"` passes ✅

### Duplicate Check (Lines 38–47)

```js
const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
if (existing.rows.length > 0)
  return res.status(400).json({ success: false, message: 'This email is already registered' });
```

**`SELECT id FROM users WHERE email = $1`** — only select the `id` column (not `*`) — fastest possible check. We don't need any other data; we just want to know if a row exists.

**`existing.rows.length > 0`** — if the array has at least one element, the email is taken.

The same pattern repeats for `roll_number` duplicate check (lines 43–47).

### `bcrypt.hash(password, 10)` — Line 51

```js
const hashed = await bcrypt.hash(password, 10);
```

**`bcrypt.hash(plainText, costFactor)`**
- `password` — the plain text password from `req.body`
- `10` — cost factor (number of bcrypt rounds). 2^10 = 1024 iterations. At this cost, hashing takes ~100ms.
- Returns a promise that resolves to the hash string
- `await` pauses here until hashing completes

**`const hashed`** — stores the result: a string like `"$2a$10$someHashHere..."`
- `$2a$` — bcrypt version
- `10$` — cost factor
- Next 22 chars — the randomly generated **salt** (random data mixed in before hashing, preventing rainbow table attacks)
- Remaining chars — the actual hash

### Initials Generation (Line 52)

```js
const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
```

**`name.split(' ')`** — splits the name string at spaces into an array
- `"Alice Smith"` → `['Alice', 'Smith']`
- `"Bob"` → `['Bob']`

**`.map(w => w[0])`** — for each word `w`, take index `[0]` (first character)
- `['Alice', 'Smith']` → `['A', 'S']`

**`.join('')`** — join array elements with no separator
- `['A', 'S']` → `'AS'`

**`.toUpperCase()`** — convert to uppercase (handles lowercase names)
- `'as'` → `'AS'`

**`.slice(0, 2)`** — keep only first 2 characters
- `'ASM'` (three-word name) → `'AS'`

### INSERT and RETURNING * (Lines 54–59)

```js
const result = await pool.query(
  `INSERT INTO users (name, email, password, role, roll_number, avatar_initials)
   VALUES ($1, $2, $3, $4, $5, $6)
   RETURNING id, name, email, role, roll_number, avatar_initials`,
  [name, email, hashed, role, roll_number || null, initials]
);
```

**`roll_number || null`** — if `roll_number` is an empty string or falsy, store `NULL` in the database instead of an empty string. `NULL` in PostgreSQL is the correct way to represent "no value."

**`RETURNING id, name, email, role, roll_number, avatar_initials`** — returns specific columns (NOT `*`)
- Excludes the `password` column intentionally — never include hashed passwords in responses

### `res.status(201).json({ success: true, token: generateToken(user), user })`

**`generateToken(user)`** — creates the JWT for the new user
- The user object from `result.rows[0]` has `id`, `role`, `name`, `email` — all needed for the token payload

**`user`** — shorthand property. Same as `user: user`. The Flutter app stores this user object to populate the profile screen.

---

## Lines 70–94 — `login` function

```js
const login = async (req, res) => {
  const { identifier, password } = req.body;
  ...
};
```

### `const { identifier, password } = req.body;`

**`identifier`** — not `email` or `roll_number` — a single field that accepts EITHER
- Flutter sends: `{ identifier: 'alice@adtu.in', password: '...' }` or `{ identifier: 'CS2021001', password: '...' }`
- This gives users flexibility — they can log in with email OR roll number

### `const isEmail = identifier.includes('@');`

**`.includes('@')`** — String method. Returns `true` if the string contains `@`.
- Email addresses contain `@`; roll numbers don't
- This determines which database column to search

### Determining the Query (Lines 77–79)

```js
const isEmail = identifier.includes('@');
const query = isEmail
  ? 'SELECT * FROM users WHERE email = $1'
  : 'SELECT * FROM users WHERE roll_number = $1';
```

**Ternary operator** `condition ? valueIfTrue : valueIfFalse`
- If `isEmail` is true → search by email
- If false → search by roll_number

### Generic Error Message (Lines 84–85)

```js
if (result.rows.length === 0)
  return res.status(401).json({ success: false, message: 'Invalid credentials' });
```

**"Invalid credentials"** — intentionally vague. We don't say "Email not found" or "Wrong password."

Why? If we say "Email not found," an attacker knows a specific email doesn't have an account. If we say "Wrong password," they know the email IS registered. The generic message reveals nothing — a security principle called **not leaking enumeration information**.

### `bcrypt.compare(password, user.password)` — Line 88

```js
const match = await bcrypt.compare(password, user.password);
if (!match)
  return res.status(401).json({ success: false, message: 'Invalid credentials' });
```

**`bcrypt.compare(plainText, hash)`**
- Takes the entered plain text password and the stored hash
- Re-hashes the plain text using the salt embedded in the stored hash
- Compares the result to the stored hash
- Returns `true` if they match, `false` otherwise
- Takes ~100ms (same as hashing) — this is intentional and cannot be sped up

### Removing Password from Response (Line 92)

```js
const { password: _, ...safeUser } = user;
```

**`const { password: _, ...safeUser } = user;`** — a clever destructuring trick:
- `password: _` — extracts the `password` property and renames it to `_` (a convention for "unused variable")
- `...safeUser` — **rest in destructuring**: collects ALL OTHER properties into `safeUser`
- Result: `safeUser` has everything EXCEPT `password`
- This ensures the hashed password is never sent to the client

---

## Lines 101 — `getMe` function

```js
const getMe = async (req, res) => res.json({ success: true, user: req.user });
```

**One-liner arrow function** (no `{}` block needed for single expression return)
- `req.user` was set by the `protect` middleware
- Simply returns the cached user data from the JWT — no database query at all

---

## Lines 108–132 — `updateProfile` function

```js
const updateProfile = async (req, res) => {
  const { name, dob } = req.body;
  const avatar_url = req.file?.path || null;
  const fields = []; const values = []; let idx = 1;
  ...
};
```

**`req.file?.path`** — optional chaining
- `req.file` — set by the `upload.single('avatar')` middleware (multer)
- `?.path` — if `req.file` exists, get its `.path` property. If `req.file` is undefined (no file uploaded), return `undefined`
- `|| null` — convert `undefined` to `null` for the database

**Dynamic SET clause** (same pattern as `academicEventController`):
```js
const fields = []; const values = []; let idx = 1;
if (name) { fields.push(`name = $${idx++}`); values.push(name); ... }
```

**`idx++`** — **post-increment** operator
- Returns the current value of `idx` FIRST, then increments it
- `$${idx++}` when `idx=1`: uses `1` in the template, then `idx` becomes `2`
- Different from `++idx` (pre-increment): that would increment first, then use

**`fields.join(', ')`** — joins all SET clauses: `"name = $1, avatar_initials = $2, dob = $3"`

---

## Lines 138–172 — `changePassword` function

**The security pattern:**
1. Get the user from DB using `req.user.id` (their proven identity from the JWT)
2. `bcrypt.compare(currentPassword, user.password)` — verify they know their current password
3. Validate new password strength
4. `bcrypt.hash(newPassword, 10)` — hash the new password
5. UPDATE the database

**Why verify current password?** — If someone gains brief access to an authenticated session (e.g., you walk away from your computer), they shouldn't be able to change the password without knowing the current one. This is an extra layer of protection.

---

## Line 174 — `module.exports = {...}`

```js
module.exports = { register, login, getMe, updateProfile, changePassword };
```

All 5 functions exported for `authRoutes.js` to use.

---

## Complete Security Flow

```
Registration:
  plain password → bcrypt.hash(pw, 10) → stored hash in DB
  No plain password EVER stored

Login:
  user enters password → bcrypt.compare(entered, stored_hash)
  → match? → jwt.sign({ id, role, name, email }, JWT_SECRET, { expiresIn: '7d' })
  → token sent to Flutter → Flutter stores it locally
  → sent in every request: "Authorization: Bearer <token>"

Every protected request:
  JWT received → jwt.verify(token, JWT_SECRET)
  → decode payload → req.user = { id, role, name, email }
  → controller uses req.user.id to identify the user
  → no additional DB query needed for user identity
```
