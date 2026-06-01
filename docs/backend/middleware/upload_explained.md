# Word-by-Word Deep Dive: `backend/middleware/upload.js`

> This file defines the **file upload middleware** — the system that receives binary files from the Flutter app and stores them in Supabase Storage. It uses a custom storage engine built on top of the `multer` library. This is one of the most technically sophisticated files in the backend.

---

## Before Reading — Key Concepts

### What is Multer?
`multer` is an Express middleware for handling `multipart/form-data` — the encoding format used when uploading files via HTTP. When a Flutter app uploads a file, it sends a `multipart/form-data` request containing both the file binary and any text fields.

Without multer, Express can't parse these requests — `req.body` would be empty and the file data would be lost.

### What is a Storage Engine?
Multer is designed to be storage-agnostic. By default it offers:
- `multer.memoryStorage()` — keep file in RAM as a Buffer (temporary)
- `multer.diskStorage()` — save file to local disk

But you can write a **custom storage engine** — a class with `_handleFile` and `_removeFile` methods. Multer calls these methods and you decide what to do with the file data. Here, we stream it directly to Supabase.

### What is a Stream?
Instead of loading the entire file into memory at once (problematic for large files), a **stream** delivers the file in small chunks as they arrive over the network. The `file.stream` in multer is a Node.js `Readable` stream — you listen for `'data'` events to receive chunks and `'end'` event when all data has arrived.

### What is a Buffer?
A `Buffer` is a fixed-size chunk of raw binary data in Node.js memory. `Buffer.concat(chunks)` takes an array of small buffers and merges them into one large buffer — the complete file in memory.

---

## Line 1 — `const multer = require('multer');`

**`multer`** — the npm package for handling multipart file uploads in Express. Intercepts the incoming request before it reaches your controller.

---

## Line 2 — `const { supabase, BUCKET } = require('../config/supabase');`

**`supabase`** — the Supabase client instance (for calling `supabase.storage.from(BUCKET).upload(...)`)

**`BUCKET`** — the constant `'files'` — the Supabase storage bucket name

---

## Line 4 — `const FOLDER = 'edusync';`

**`const FOLDER`** — a constant string. All uploaded files go into a sub-folder called `edusync` inside the `files` bucket.

Final storage path example: `edusync/1716450000000-Report.pdf`
Full public URL: `https://your-project.supabase.co/storage/v1/object/public/files/edusync/1716450000000-Report.pdf`

Using a folder prefix organizes files and makes it easier to manage/clean them separately.

---

## Lines 13–58 — `class SupabaseStorage`

```js
class SupabaseStorage {
  async _handleFile(req, file, cb) { ... }
  _removeFile(req, file, cb) { ... }
}
```

### `class SupabaseStorage`

**`class`** — JavaScript keyword for defining a class (ES6+). A class is a template for creating objects.

**`SupabaseStorage`** — the class name. By convention, class names are PascalCase (each word capitalized).

This class implements the **multer storage engine interface**. Multer requires exactly two methods:
- `_handleFile(req, file, cb)` — called to save the file
- `_removeFile(req, file, cb)` — called if an error occurs and multer needs to clean up

---

## Lines 14–50 — `_handleFile` method

```js
async _handleFile(req, file, cb) {
  const chunks = [];
  file.stream.on('data', (chunk) => chunks.push(chunk));
  file.stream.on('error', cb);
  file.stream.on('end', async () => {
    try {
      const buffer = Buffer.concat(chunks);
      const safeName = file.originalname.replace(/\s+/g, '_');
      const storagePath = `${FOLDER}/${Date.now()}-${safeName}`;

      const { error } = await supabase.storage
        .from(BUCKET)
        .upload(storagePath, buffer, { contentType: file.mimetype, upsert: false });

      if (error) return cb(error);

      const { data } = supabase.storage.from(BUCKET).getPublicUrl(storagePath);

      cb(null, {
        path: data.publicUrl,
        filename: file.originalname,
        size: buffer.length,
        storagePath,
      });
    } catch (err) {
      cb(err);
    }
  });
}
```

### `async _handleFile(req, file, cb)`

**`async`** — because we `await` the Supabase upload inside it

**`req`** — the Express request object (available but not used here — multer passes it for context)

**`file`** — the file object provided by multer. Has properties:
- `file.stream` — a Node.js Readable stream of the file data
- `file.originalname` — the filename the user uploaded (e.g., `"My Report.pdf"`)
- `file.mimetype` — the file's MIME type (e.g., `"application/pdf"`, `"image/png"`)

**`cb`** — **callback function** — multer's callback pattern (pre-async/await style)
- `cb(error)` — signals failure to multer
- `cb(null, fileInfo)` — signals success with the file info object

### `const chunks = [];`

An empty array that will collect the stream's data chunks. Each chunk is a `Buffer` of binary data.

### `file.stream.on('data', (chunk) => chunks.push(chunk));`

**`file.stream.on('data', callback)`** — registers a listener for the `'data'` event
- Every time a chunk of file data arrives over the network, this fires
- `(chunk) => chunks.push(chunk)` — appends each chunk to the `chunks` array
- The chunk is a `Buffer` (raw binary)

**For a 5MB file:** This might fire 40+ times with ~128KB chunks each. We collect them all.

### `file.stream.on('error', cb);`

**`'error'`** event — if the stream encounters an error (network dropped, client disconnected):
- Calls `cb` with the error object
- Tells multer something went wrong — multer will then call `_removeFile` to clean up

### `file.stream.on('end', async () => {...})`

**`'end'`** event — fires when the ENTIRE file has been received (all chunks delivered)

**`async () => {...}`** — async arrow function as the callback, needed because we `await` inside it

### `const buffer = Buffer.concat(chunks);`

**`Buffer.concat(array)`** — Node.js built-in. Takes an array of Buffers and concatenates them into one Buffer.
- `chunks = [Buffer(128KB), Buffer(128KB), Buffer(128KB), ...]`
- `Buffer.concat(chunks)` → one `Buffer(384KB+)` — the complete file

### `const safeName = file.originalname.replace(/\s+/g, '_');`

**`file.originalname`** — e.g., `"My Assignment Report.pdf"`

**`.replace(pattern, replacement)`** — String method. Replaces matches of `pattern` with `replacement`.

**`/\s+/g`** — a regular expression:
- `\s` — matches any whitespace character (space, tab, newline)
- `+` — one or more of the preceding pattern
- `g` — the **global flag**: replace ALL occurrences, not just the first
- Without `g`: `"My Assignment.pdf"` → `"My_Assignment.pdf"` (only first space)
- With `g`: `"My Assignment.pdf"` → `"My_Assignment.pdf"` (all spaces)

**`'_'`** — replace spaces with underscores

**Why sanitize?** — URLs with spaces are problematic. `"My Report.pdf"` in a URL becomes `"My%20Report.pdf"` which can cause issues in some contexts. Underscores are safe.

### `` const storagePath = `${FOLDER}/${Date.now()}-${safeName}`; ``

**`Date.now()`** — JavaScript built-in. Returns the current timestamp in **milliseconds** since January 1, 1970 (Unix epoch).
- Example: `1716450000000` (a 13-digit number)
- This number is unique per millisecond — virtually impossible for two uploads to have the same timestamp
- Used as a prefix to make filenames unique even if users upload files with the same name

**Template literal** combines:
- `FOLDER` = `'edusync'`
- `/` — path separator
- `Date.now()` = timestamp
- `-` — separator between timestamp and name
- `safeName` = `'My_Report.pdf'`

Result: `'edusync/1716450000000-My_Report.pdf'`

### `supabase.storage.from(BUCKET).upload(storagePath, buffer, {...})`

**`supabase.storage`** — the Storage API of the Supabase client

**`.from(BUCKET)`** — selects the bucket (`'files'`)

**`.upload(path, data, options)`** — uploads data to the specified path

- `storagePath` — where in the bucket to store the file
- `buffer` — the complete file binary data
- `{ contentType: file.mimetype }` — tells Supabase what type of file this is. Supabase sets the correct HTTP `Content-Type` header when serving the file, so browsers open PDFs as PDFs not as binary downloads.
- `{ upsert: false }` — don't overwrite if a file at this path already exists. Since we use timestamps in the path, this should never happen, but `false` is the safe default.

**`const { error }`** — destructure only `error` from the response object

### `if (error) return cb(error);`

If upload failed, call `cb(error)` to tell multer there was a problem. `return` stops further execution.

### `supabase.storage.from(BUCKET).getPublicUrl(storagePath)`

**`getPublicUrl(path)`** — generates the public HTTP URL for the stored file
- This is a **synchronous** method (no `await`) — it just constructs the URL string locally
- Returns `{ data: { publicUrl: 'https://...' } }`
- The URL format: `{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}`

### `cb(null, { path, filename, size, storagePath })`

**`cb(null, fileInfo)`** — tells multer the upload succeeded. `null` as first argument = no error.

The second argument becomes `req.file` in the controller:
- **`path: data.publicUrl`** → `req.file.path` — controllers read this as the file's URL (stored in DB)
- **`filename: file.originalname`** → `req.file.filename` — original filename for display
- **`size: buffer.length`** → file size in bytes
- **`storagePath`** → Supabase internal path (used for deletion if needed)

**Why use `path` for the URL?** — Multer's disk storage uses `path` for the local file path. By putting the Supabase URL in `path`, controllers work the same way without any changes: `req.file.path` always gives the file's location URL.

---

## Lines 52–57 — `_removeFile` method

```js
_removeFile(req, file, cb) {
  if (file.storagePath) {
    supabase.storage.from(BUCKET).remove([file.storagePath]).catch(() => {});
  }
  cb(null);
}
```

Called by multer when it needs to clean up a file (e.g., if validation fails after upload).

**`file.storagePath`** — the path in Supabase where the file was uploaded

**`supabase.storage.from(BUCKET).remove([storagePath])`** — deletes the file from Supabase Storage
- `remove([])` takes an **array** of paths (can delete multiple at once)
- `.catch(() => {})` — ignore any deletion errors (best-effort cleanup)

**`cb(null)`** — signal success to multer (no error from removal)

---

## Lines 60–70 — `fileFilter`

```js
const fileFilter = (req, file, cb) => {
  const blockedMimes = [
    'application/x-msdownload',
    'application/x-bat',
    'application/x-msdos-program',
  ];
  if (blockedMimes.includes(file.mimetype)) {
    return cb(new Error('Executable files are not allowed for security reasons'), false);
  }
  cb(null, true);
};
```

**`fileFilter`** — a multer option. Called before `_handleFile`. Lets you accept or reject a file before uploading.

**`blockedMimes`** — an array of MIME types for executable files:
- `'application/x-msdownload'` — `.exe` files (Windows executables)
- `'application/x-bat'` — `.bat` files (Windows batch scripts)
- `'application/x-msdos-program'` — `.com` files (MS-DOS programs)

**`blockedMimes.includes(file.mimetype)`** — checks if the uploaded file's MIME type is in the blocked list

**`cb(new Error('...'), false)`** — reject the file:
- `new Error('...')` — the error object (multer will forward this)
- `false` — explicitly reject the file

**`cb(null, true)`** — accept the file (no error, allowed)

**Security rationale:** Allowing executable uploads would let malicious users upload virus files that other users might download and run.

---

## Lines 72–76 — Creating the Multer Instance

```js
const upload = multer({
  storage  : new SupabaseStorage(),
  fileFilter,
  limits   : { fileSize: 50 * 1024 * 1024 },
});
```

**`multer({...})`** — creates the multer middleware with configuration

**`storage: new SupabaseStorage()`** — instantiate our custom storage engine
- `new` — create an instance of the class
- multer will call `instance._handleFile(...)` for every uploaded file

**`fileFilter`** — shorthand property (same as `fileFilter: fileFilter`) — our filter function above

**`limits: { fileSize: 50 * 1024 * 1024 }`**
- `fileSize` — maximum file size in bytes
- `50 * 1024 * 1024` = 50 MB
- If client uploads a larger file, multer automatically rejects it with a `LIMIT_FILE_SIZE` error before calling `_handleFile`

---

## Line 78 — `module.exports = upload;`

Exports the configured multer instance. Used in routes:
```js
const upload = require('../middleware/upload');
router.post('/', protect, upload.single('file'), sendMessage);
```

**`upload.single('fieldname')`** — processes one file with the given form field name. After this runs, `req.file` contains the file info.

**`upload.array('files', 5)`** — for multiple files (not used here).

---

## Complete Upload Flow

```
Flutter user selects a file and sends:
  POST /api/channels/7/messages
  Content-Type: multipart/form-data
  body: { content: "See attachment", file: <binary data> }
         │
         ▼
multer intercepts (before controller runs)
         │
         ├─ fileFilter: is it an .exe? → reject with 400
         │
         ├─ limits: is it > 50MB? → reject with 413
         │
         └─ _handleFile: upload to Supabase
              │  collect stream chunks → Buffer.concat → complete file
              │  supabase.storage.upload('edusync/timestamp-filename', buffer)
              │  getPublicUrl('edusync/timestamp-filename')
              └─ req.file = { path: 'https://supabase.co/...', filename: 'file.pdf', ... }
         │
         ▼
messageController.sendMessage(req, res)
  reads req.file.path → stores URL in messages table
  reads req.file.filename → stores filename in messages table
```
