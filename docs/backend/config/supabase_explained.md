# Word-by-Word Deep Dive: `backend/config/supabase.js`

> This file sets up the connection to **Supabase Storage** — a cloud file storage service (like AWS S3 but simpler). Your backend uses it to store all uploaded files (PDFs, images, docs) that users send in messages. PostgreSQL stores the file's URL; the actual file lives in Supabase Storage.

---

## Before Reading — What is Supabase Storage?

Supabase is an open-source Firebase alternative. Among its features is **Object Storage** — a place to upload and serve files via URLs, similar to Amazon S3. Files are organized in **buckets** (like folders).

In this app:
- A user uploads a PDF in the Flutter app
- The backend uploads it to Supabase Storage → gets a public URL
- That URL is stored in the `messages` or `assignments` table in PostgreSQL
- The Flutter app displays the file using that URL

### Why Supabase instead of PostgreSQL for files?
PostgreSQL stores **structured data** (text, numbers, dates). Storing binary files (PDFs, images) directly in PostgreSQL (using `bytea` type) is extremely inefficient — it bloats the database and makes backups huge. Cloud object storage is designed specifically for binary files.

---

## The Full File

```js
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
);

const BUCKET = 'files';

async function ensureBucket() {
  const { error } = await supabase.storage.createBucket(BUCKET, {
    public: true,
    allowedMimeTypes: null,
    fileSizeLimit: 52428800,
  });
  if (error && !error.message.includes('already exists')) {
    console.warn('[Supabase] Could not create bucket:', error.message);
  } else {
    console.log(`[Supabase] Storage bucket "${BUCKET}" ready.`);
  }
}

module.exports = { supabase, BUCKET, ensureBucket };
```

---

## Line 1 — `const { createClient } = require('@supabase/supabase-js');`

**`{ createClient }`** — destructured import. Pulls only `createClient` from the package.

**`require('@supabase/supabase-js')`** — loads the official Supabase JavaScript client library
- The `@` prefix means it's a **scoped npm package** — `@supabase/supabase-js` is in the `supabase` npm organization
- This package provides the entire Supabase client: database, auth, storage, etc.

**`createClient`** — a factory function. You call it with your project URL and API key to get a configured Supabase client instance.

---

## Lines 3–6 — Creating the Supabase Client

```js
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
);
```

**`createClient(url, key)`** — takes two arguments:

**`process.env.SUPABASE_URL`**
- Your Supabase project's base URL
- Format: `https://xyzcompany.supabase.co`
- Found in your Supabase dashboard under Project Settings → API

**`process.env.SUPABASE_SERVICE_KEY`**
- The **service role key** (also called service key)
- This is the most powerful key — it bypasses all Row Level Security (RLS) policies
- Suitable for server-side use only (never expose in client-side code)
- Different from the `anon` key (which respects RLS and is safe for clients)
- Stored in `.env` — never hardcoded

The resulting `supabase` object has:
- `supabase.storage` — for file operations (upload, download, delete, list)
- `supabase.from('table')` — for database queries (not used here; we use `pg` for that)

---

## Line 8 — `const BUCKET = 'files';`

**`const BUCKET`** — a constant (ALL_CAPS by convention for "magic strings" that don't change)

**`'files'`** — the name of the Supabase Storage bucket where all uploaded files go
- A bucket is like a top-level folder in cloud storage
- All files in this app (assignment attachments, message files, etc.) go into this one bucket
- Using a constant prevents typos — `BUCKET` is used in multiple places, not `'files'` repeated everywhere

---

## Lines 14–26 — `async function ensureBucket()`

```js
async function ensureBucket() {
  const { error } = await supabase.storage.createBucket(BUCKET, {
    public: true,
    allowedMimeTypes: null,
    fileSizeLimit: 52428800,
  });
  if (error && !error.message.includes('already exists')) {
    console.warn('[Supabase] Could not create bucket:', error.message);
  } else {
    console.log(`[Supabase] Storage bucket "${BUCKET}" ready.`);
  }
}
```

**`async function ensureBucket()`**
- `async` — asynchronous function (uses `await` inside)
- `function` keyword syntax (alternative to arrow function `const ensureBucket = async () => {}`)
- Both are equivalent here; this style is called a **function declaration** and is slightly more traditional
- Called once at server startup from `server.js`: `await ensureBucket()`

### `const { error } = await supabase.storage.createBucket(...)`

**`supabase.storage`** — the storage sub-client from the Supabase SDK

**`.createBucket(name, options)`** — creates a new storage bucket
- If bucket already exists, it doesn't throw — it returns an `error` object with a message containing "already exists"
- Returns an object: `{ data: {...}, error: null }` (success) or `{ data: null, error: {...} }` (failure)

**`const { error }`** — destructures only the `error` property from the returned object
- If success: `error` is `null`
- If failure: `error` is an object with `.message`, `.code`, etc.

**`BUCKET`** — the string `'files'` (our constant from line 8)

### The Options Object:

**`public: true`**
- Makes the bucket **publicly readable** — files can be accessed via their URL without authentication
- Required for the Flutter app to display files using just the URL
- If `false`, every file access would need a signed URL (more complex)

**`allowedMimeTypes: null`**
- `null` means **allow all file types** (PDFs, images, documents, videos, etc.)
- Could restrict to e.g. `['application/pdf', 'image/*']` — but `null` is simpler for an educational app

**`fileSizeLimit: 52428800`**
- Maximum file size in bytes
- `52428800 = 50 × 1024 × 1024 = 50 MB`
- Files larger than 50MB are rejected
- Supabase free tier limits: 1 GB total storage, 50 MB per file — this matches the per-file limit

---

### Lines 21–25 — Handling the Result

```js
if (error && !error.message.includes('already exists')) {
  console.warn('[Supabase] Could not create bucket:', error.message);
} else {
  console.log(`[Supabase] Storage bucket "${BUCKET}" ready.`);
}
```

**`error &&`**
- First part of the AND condition
- Is there an error at all? If `error` is `null` (success), the whole condition is `false`

**`!error.message.includes('already exists')`**
- `.includes('already exists')` — checks if the error message contains that substring
- `!` — NOT. So: "the error message does NOT say 'already exists'"
- This condition is `true` when the error is something other than "bucket already exists"
- **Why ignore "already exists"?** — Every time the server restarts, `ensureBucket()` runs. The bucket was already created on the first startup. We don't want an error log every time the server restarts. This filters it out.

**Combined logic:**
- Error is null → `if` is false → `else` runs → logs "ready" ✅
- Error = "already exists" → `if` is false (because `!true = false`) → `else` runs → logs "ready" ✅
- Error = some other error → `if` is true → `warn` logs the actual problem ⚠️

**`console.warn`** — like `console.log` but marks as a warning (yellow in some terminals, treated differently by log systems)

**`` `[Supabase] Storage bucket "${BUCKET}" ready.` ``**
- Template literal. `${BUCKET}` is replaced with `'files'`
- Produces: `[Supabase] Storage bucket "files" ready.`

---

## Line 28 — `module.exports = { supabase, BUCKET, ensureBucket };`

Exports three things:

**`supabase`** — the client instance. Other files import this to upload files:
```js
const { supabase, BUCKET } = require('../config/supabase');
await supabase.storage.from(BUCKET).upload(filePath, buffer);
```

**`BUCKET`** — the bucket name constant. Exported so other files don't hardcode `'files'`.

**`ensureBucket`** — the setup function. Imported and called in `server.js` at startup:
```js
const { ensureBucket } = require('./config/supabase');
server.listen(PORT, async () => {
  await ensureBucket();
});
```

---

## How File Uploads Work End-to-End

```
Flutter app picks a file
        │
        │  POST /api/channels/:id/messages (multipart/form-data)
        ▼
upload middleware (multer) — receives the file binary data, puts it in req.file
        │
        ▼
messageController.js
        │  const { supabase, BUCKET } = require('../config/supabase');
        │  await supabase.storage.from(BUCKET).upload('path/filename', req.file.buffer)
        │  → gets back a public URL: https://xyzcompany.supabase.co/storage/v1/object/public/files/path/filename
        ▼
INSERT INTO messages (channel_id, sender_id, file_url, file_name) VALUES (...)
        │
        ▼
Flutter app receives the message with file_url
        │  displays file using the URL
```

---

## Summary Table

| Line | Code | What it does |
|---|---|---|
| 1 | `createClient` import | Load Supabase SDK factory function |
| 3–6 | `createClient(url, key)` | Create authenticated Supabase client |
| 8 | `const BUCKET = 'files'` | Define bucket name as a reusable constant |
| 14 | `async function ensureBucket()` | Creates the bucket if it doesn't exist |
| 15–19 | `createBucket(BUCKET, {...})` | Create public bucket, 50MB limit, all file types |
| 21–25 | `if (error && ...)` | Ignore "already exists" error, warn on real errors |
| 28 | `module.exports` | Export client, bucket name, and setup function |
