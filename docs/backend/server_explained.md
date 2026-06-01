# Word-by-Word Deep Dive: `backend/server.js`

> This is the **entry point** of the entire backend — the file that starts the server. It wires together everything: Express app, CORS, security headers, rate limiting, Socket.IO, all route files, error handling, and the HTTP server. Understanding this file means understanding how the whole backend starts up and how every request flows through the system.

---

## Before Reading — What Happens When the Server Starts?

1. Node.js runs `server.js` top-to-bottom
2. All `require()` calls load modules into memory
3. Express app (`app`) is configured with middleware and routes
4. HTTP server (`server`) is created from the Express app
5. Socket.IO (`io`) is attached to the HTTP server
6. `server.listen(PORT)` starts listening for connections
7. On startup: Supabase bucket is verified

---

## Lines 1–2 — Before Everything Else

```js
require('dotenv').config();
require('express-async-errors');
```

### `require('dotenv').config();`

Must be the **very first line** — loads `.env` into `process.env` before any other module reads env vars.
- `require('dotenv')` — loads the module
- `.config()` — immediately calls the config method (note: no variable assignment needed — the side effect is what matters)

### `require('express-async-errors');`

**`express-async-errors`** — a "monkey-patching" library. When required, it modifies Express's internal routing so that `async` functions that throw errors automatically pass them to the error handler (via `next(err)`).

**"Monkey-patching"** — modifying someone else's code at runtime by overriding their methods/properties. Here, it overrides Express's route handler wrapper to wrap every handler in a try/catch.

Without this: every `async` controller would need:
```js
try { ... } catch(err) { next(err); }
```
With this: throw anywhere, `errorHandler` catches it.

---

## Lines 4–15 — Importing Dependencies

```js
const express   = require('express');
const cors      = require('cors');
const http      = require('http');
const helmet    = require('helmet');
const rateLimit = require('express-rate-limit');
const { Server } = require('socket.io');
```

**`express`** — the web framework

**`cors`** — Cross-Origin Resource Sharing middleware. Controls which origins (domains) can make requests to the API.

**`http`** — Node.js **built-in** module (no npm install needed) for creating HTTP servers
- Why not use Express's built-in server? — Socket.IO needs access to the raw HTTP server, not just the Express app

**`helmet`** — sets security HTTP response headers automatically. Protects against XSS, clickjacking, content sniffing, etc.

**`rateLimit`** — global rate limiter (200 requests/IP/15min)

**`{ Server }`** — the Socket.IO server class (destructured — only this class is needed from socket.io)

```js
const errorHandler  = require('./middleware/errorHandler');
const socketHandler = require('./socket/socketHandler');
const { setIO }     = require('./controllers/messageController');
const compression   = require('compression');
const { ensureBucket } = require('./config/supabase');
```

**`socketHandler`** — a function that sets up all Socket.IO event listeners (join room, send message, etc.)

**`{ setIO }`** — function from `messageController.js` that stores the `io` instance so REST controllers can emit events

**`compression`** — gzip middleware. Compresses all API responses before sending them. Typically reduces JSON size by ~80%.

**`ensureBucket`** — called on startup to make sure the Supabase storage bucket exists

---

## Lines 17–28 — Importing All Route Files

```js
const authRoutes         = require('./routes/authRoutes');
const channelRoutes      = require('./routes/subjectRoutes');
const messageRoutes      = require('./routes/messageRoutes');
const assignmentRoutes   = require('./routes/assignmentRoutes');
const announcementRoutes = require('./routes/announcementRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const actualNotesRoutes  = require('./routes/actualNotesRoutes');
const projectRoutes      = require('./routes/projectRoutes');
const academicEventRoutes = require('./routes/academicEventRoutes');
const enrollmentRoutes   = require('./routes/enrollmentRoutes');
const teacherRoutes      = require('./routes/teacherRoutes');
const downloadRoutes     = require('./routes/downloadRoutes');
```

Each `const` holds a router object that defines routes for a specific feature area. They're mounted below with `app.use(...)`.

---

## Lines 30–31 — Creating the Server

```js
const app = express();
const server = http.createServer(app);
```

### `const app = express();`

**`express()`** — calling the express function creates a new Express application instance.
`app` is an object with methods like `app.use()`, `app.get()`, `app.listen()`, etc.

### `const server = http.createServer(app);`

**`http.createServer(app)`** — creates a raw Node.js HTTP server, passing the Express app as the request handler.

**Why not just `app.listen(PORT)`?** — `app.listen()` would work for HTTP only, but Socket.IO needs the underlying `http.Server` object (not the Express app) to attach to. By creating the server manually, both Express and Socket.IO share the same server/port.

The relationship:
```
HTTP request → Node.js http.Server → Express app.use() chain → routes → controllers
WebSocket upgrade → Node.js http.Server → Socket.IO Server → socketHandler events
```

Both use the same `server` (same port, same connection).

---

## Lines 33–45 — CORS Configuration

```js
const allowedOrigins = [
  process.env.CLIENT_URL,
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:9090',
  'https://major-three-tau.vercel.app',
  /\.vercel\.app$/,
  ...(process.env.NODE_ENV !== 'production' ? [
    /^http:\/\/localhost:\d+$/,
    /^http:\/\/127\.0\.0\.1:\d+$/,
  ] : []),
].filter(Boolean);
```

**`allowedOrigins`** — an array of allowed origins. Mix of strings and **regular expressions**.

**`process.env.CLIENT_URL`** — e.g., `'https://myapp.vercel.app'` — the production frontend URL

**`/\.vercel\.app$/`** — a regular expression:
- `/` — regex literal delimiter
- `\.vercel\.app` — match the literal string `.vercel.app` (the `\.` escapes the dot, which otherwise means "any character" in regex)
- `$` — end of string anchor
- Matches: `preview-123.vercel.app`, `staging.vercel.app` — any Vercel deployment

**`...(process.env.NODE_ENV !== 'production' ? [...] : [])`**
- In development: add `localhost:ANY_PORT` and `127.0.0.1:ANY_PORT` regex patterns
- In production: add nothing (empty array spread = no additions)
- Flutter Web dev server picks a random port each time — the regex allows any port number

**Regex:** `/^http:\/\/localhost:\d+$/`
- `^` — start of string
- `http://` — literal (the `\/` escapes `/` inside a regex literal)
- `localhost:` — literal
- `\d+` — one or more digits (the port number)
- `$` — end of string

**`.filter(Boolean)`** — removes any falsy values. If `process.env.CLIENT_URL` is `undefined` (not set), it would add `undefined` to the array. `filter(Boolean)` removes it. `Boolean(undefined) = false` → filtered out.

---

## Lines 47–57 — CORS Options (Custom Checker)

```js
const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    const allowed = allowedOrigins.some(o =>
      o instanceof RegExp ? o.test(origin) : o === origin
    );
    if (allowed) callback(null, true);
    else callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
};
```

**`origin: (origin, callback)`** — instead of a simple array, we use a FUNCTION that checks each request's origin:
- `origin` — the `Origin` header from the request (e.g., `'http://localhost:9090'`)
- `callback(error, allowed)` — call with `null, true` to allow, or an Error to block

**`if (!origin) return callback(null, true);`**
- Requests with no `Origin` header (Postman, server-to-server calls, health checks) are allowed
- Browsers always send `Origin` for cross-origin requests; non-browser tools don't

**`allowedOrigins.some(o => ...)`**
- `.some(callback)` — Array method. Returns `true` if AT LEAST ONE element satisfies the callback.
- `o instanceof RegExp` — checks if the element is a regular expression (not a string)
- `? o.test(origin)` — if regex: test the origin against it. `.test(string)` returns true/false.
- `: o === origin` — if string: exact equality comparison

**`credentials: true`** — allows cookies and Authorization headers to be sent cross-origin

---

## Lines 59–63 — Socket.IO Setup

```js
const io = new Server(server, {
  cors: { origin: allowedOrigins, methods: ['GET', 'POST'], credentials: true },
});
socketHandler(io);
setIO(io);
```

**`new Server(server, {...})`** — creates a Socket.IO server attached to the HTTP `server`. Same CORS rules as Express.

**`socketHandler(io)`** — passes `io` to `socketHandler.js` which sets up all event listeners (`connection`, `join:channel`, `message:send`, `disconnect`, etc.)

**`setIO(io)`** — stores `io` in `messageController.js` so REST endpoints can call `io.emit(...)`. This is how creating an announcement (REST) can still trigger a real-time event (Socket.IO).

---

## Lines 65–68 — Core Middleware Stack

```js
app.use(compression());
app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
```

**`app.use(middleware)`** — registers middleware that runs on EVERY request before routes.

**`compression()`** — gzip compression. Middleware that intercepts responses and compresses them. Flutter receives less data → faster loading.

**`cors(corsOptions)`** — applies CORS headers based on our custom origin checker. Without this, browsers would block responses.

**`express.json()`** — parses incoming request bodies with `Content-Type: application/json`. Makes `req.body` available as a JS object. Without it, `req.body` is `undefined`.

**`express.urlencoded({ extended: true })`** — parses `application/x-www-form-urlencoded` bodies (HTML form submissions). `extended: true` uses the `qs` library for rich nested objects.

---

## Lines 72–85 — Helmet Security Headers

```js
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc : ["'self'"],
      scriptSrc  : ["'self'"],
      styleSrc   : ["'self'", "'unsafe-inline'"],
      imgSrc     : ["'self'", 'data:', 'https://*.supabase.co'],
      connectSrc : ["'self'", ..., 'https://*.supabase.co'],
      frameSrc   : ["'self'", 'https://docs.google.com', ...],
      mediaSrc   : ["'self'", 'https://*.supabase.co'],
    },
  },
}));
```

**Content Security Policy (CSP)** — a security header that tells browsers what content they're allowed to load. Prevents XSS attacks by whitelisting sources.

**`defaultSrc: ["'self'"]`** — default: only load resources from the same domain

**`scriptSrc: ["'self'"]`** — only execute scripts from the same domain (no inline scripts, no CDN)

**`styleSrc: ["'self'", "'unsafe-inline'"]`** — allow inline styles (needed for some UI frameworks)

**`imgSrc: ["'self'", 'data:', 'https://*.supabase.co']`**
- `data:` — allow data URIs (base64-encoded images in CSS)
- `https://*.supabase.co` — allow images from any Supabase subdomain (file storage URLs)
- `*.supabase.co` — the `*` is a wildcard for any subdomain

**`frameSrc: ["'self'", 'https://docs.google.com']`** — allow iframes from Google Docs (for PDF preview)

---

## Lines 88–101 — Health Check and Rate Limiter

```js
app.get('/api/health', (req, res) =>
  res.json({ success: true, message: 'EduSync API is running 🚀', timestamp: new Date().toISOString() })
);

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  skip: (req) => req.path === '/api/health',
  ...
});
app.use('/api', globalLimiter);
```

**Health check BEFORE rate limiter** — crucial ordering. If the rate limiter came first, cron job pings (to keep the server awake on free-tier hosting) would count toward the limit and eventually get blocked.

**`app.get('/api/health', ...)`** — a simple GET endpoint. Returns the current timestamp so automated monitoring can verify the API is alive.

**`new Date().toISOString()`** — returns a standardized timestamp string: `"2025-05-23T12:30:00.000Z"`

**`skip: (req) => req.path === '/api/health'`** — the rate limiter's `skip` function. Returns `true` to skip rate limiting for this specific path.

**`max: 200`** — 200 requests per IP per 15 minutes across ALL API endpoints. High enough for normal use, low enough to block bots.

---

## Lines 104–119 — Route Registration

```js
app.use('/api/auth',                      authRoutes);
app.use('/api/channels',                  channelRoutes);
app.use('/api/channels/:id/messages',     messageRoutes);
app.use('/api/channels/:id/assignments',  assignmentRoutes);
app.use('/api/channels/:id/announcements',announcementRoutes);
app.use('/api/channels/:id/notes',        actualNotesRoutes);
app.use('/api/notifications',             notificationRoutes);
app.use('/api/projects',                  projectRoutes);
app.use('/api/academic-events',           academicEventRoutes);
app.use('/api/enrollments',              enrollmentRoutes);
app.use('/api/teacher',                  teacherRoutes);
app.use('/api/file-proxy',               downloadRoutes);

app.use((req, res) => res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` }));
app.use(errorHandler);
```

**`app.use(path, router)`** — mounts a router at the given path prefix. All routes in the router are prefixed with this path.

**The nested `:id` param** — `/api/channels/:id/messages` — when this router receives a request, `:id` is in `req.params`. Routes inside `messageRoutes` use `mergeParams: true` to access it.

**The 404 catch-all** `app.use((req, res) => ...)` — matches ANY request that didn't match a previous route. Returns 404. MUST be BEFORE `errorHandler` but AFTER all routes.

**`errorHandler` — LAST** — must be last because Express calls the first matching middleware in order. The error handler must come after all routes so it only catches errors, not normal requests.

---

## Lines 121–125 — Starting the Server

```js
const PORT = process.env.PORT || 5000;
server.listen(PORT, async () => {
  console.log(`🚀 Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
  await ensureBucket();
});
```

**`process.env.PORT || 5000`**
- Cloud hosts (Render, Railway, Heroku) set `PORT` to their assigned port
- Locally, `PORT` is usually not set → fall back to `5000`

**`server.listen(PORT, callback)`** — starts listening on the port. The callback fires when the server is ready.

**`async () => {...}`** — the startup callback is async so we can `await ensureBucket()`

**`await ensureBucket()`** — ensures the Supabase 'files' bucket exists before any file uploads could happen. If the bucket is missing and a user immediately uploads, the request would fail.

---

## Full Startup Sequence

```
node server.js
        │
        ├─ dotenv.config()     — load .env into process.env
        ├─ express-async-errors — patch Express for async error handling
        ├─ require all modules — load Express, CORS, Helmet, Socket.IO, all routes
        │
        ├─ const app = express()     — create Express app
        ├─ const server = http.createServer(app)  — create HTTP server
        │
        ├─ Configure CORS origins    — build allowedOrigins array
        ├─ new Server(server, {...}) — attach Socket.IO
        ├─ socketHandler(io)         — register socket events
        ├─ setIO(io)                 — share io with controllers
        │
        ├─ app.use(compression)      — gzip middleware
        ├─ app.use(cors)             — CORS middleware
        ├─ app.use(express.json)     — JSON body parser
        ├─ app.use(helmet)           — security headers
        │
        ├─ app.get('/api/health')    — health check route
        ├─ app.use('/api', globalLimiter) — rate limiter
        │
        ├─ app.use('/api/auth', authRoutes)
        ├─ app.use('/api/channels', channelRoutes)
        ├─ ... (all other routes)
        │
        ├─ app.use(404 handler)      — catch-all for unknown routes
        ├─ app.use(errorHandler)     — global error handler (LAST)
        │
        └─ server.listen(PORT, async () => {
               console.log('🚀 Server running...')
               await ensureBucket()    — verify Supabase storage bucket
           })
```
