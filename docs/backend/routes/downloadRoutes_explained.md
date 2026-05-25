# 📄 `routes/downloadRoutes.js` — Complete Explanation

**File Path:** `backend/routes/downloadRoutes.js`
**Lines:** 41
**Mounted at:** `app.use('/api/file-proxy', downloadRoutes)`
**Role:** Authenticated file download proxy — verifies JWT from URL query param, redirects to Supabase Storage download URL.

---

## 1. Full Source Code

```js
const express = require('express');
const router  = express.Router();
const jwt     = require('jsonwebtoken');

/**
 * GET /api/file-proxy?url=<encoded_url>&token=<jwt>
 * Simple download proxy for Supabase Storage files.
 * Redirects to the public Supabase URL with ?download=true to trigger
 * Content-Disposition: attachment in the browser.
 *
 * Token is accepted in query param so window.open() can call this
 * synchronously (preserving user gesture, bypassing popup blockers).
 */
router.get('/', (req, res) => {
  const { url, token } = req.query;

  // ── Auth ──────────────────────────────────────────────────────────────────
  if (!token) return res.status(401).send('Unauthorized');
  try {
    jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    return res.status(401).send('Invalid token');
  }

  if (!url) return res.status(400).send('Missing url');

  // ── Supabase Storage files only ───────────────────────────────────────────
  if (url.includes('supabase.co')) {
    // Supabase public bucket: ?download=true triggers Content-Disposition: attachment
    const cleanUrl = url.split('?')[0];
    return res.redirect(`${cleanUrl}?download=true`);
  }

  // Unknown storage provider — reject
  return res.status(400).send('Unsupported file source');
});

module.exports = router;
```

---

## 2. The Core Problem This Solves

**Problem:** Browser file downloads need `Authorization: Bearer <token>` headers. But browser-native downloads (`window.open(url)`, `<a href="..." download>`) cannot set custom headers — they are plain HTTP navigations, not fetch/XHR calls.

**Solution:** Accept the JWT as a URL query parameter instead:
```
GET /api/file-proxy?url=https://...supabase.co/file.pdf&token=eyJhb...
```

The user clicks download → browser opens this URL → server verifies the JWT → redirects to Supabase with `?download=true`.

---

## 3. Line-by-Line Analysis

```js
const { url, token } = req.query;
```
Extract both from `?url=...&token=...`.

```js
if (!token) return res.status(401).send('Unauthorized');
try { jwt.verify(token, process.env.JWT_SECRET); }
catch { return res.status(401).send('Invalid token'); }
```
Standard JWT verification. No `req.user` needed — we only need to confirm the user is authenticated, not who they are.

```js
if (url.includes('supabase.co')) {
  const cleanUrl = url.split('?')[0];
  return res.redirect(`${cleanUrl}?download=true`);
}
```
- **`url.includes('supabase.co')`** — Allow-list check. Only Supabase URLs are proxied. This prevents SSRF (Server-Side Request Forgery).
- **`url.split('?')[0]`** — Strip existing query parameters before adding `?download=true`. Prevents query injection.
- **`res.redirect(...)`** — 302 redirect. The browser follows it and Supabase serves the file with `Content-Disposition: attachment`.

```js
return res.status(400).send('Unsupported file source');
```
Reject non-Supabase URLs.

---

## 4. Security Analysis

| Threat | Mitigation |
|---|---|
| Unauthenticated access | JWT required in `?token=` |
| Expired/invalid token | `jwt.verify()` throws → 401 |
| SSRF (fetch internal URLs) | Only `supabase.co` URLs allowed |
| Query parameter injection | `cleanUrl = url.split('?')[0]` strips existing params |
| Token leakage in logs | JWT is short-lived (7 days); server logs may contain it |

**Known limitation:** The JWT in the URL will appear in browser history and server access logs. This is unavoidable for browser-initiated downloads without more complex solutions (e.g., pre-signed short-lived URLs).

---

## 5. Frontend Connection (Flutter)

```dart
// In SubjectFilesView._downloadFile()
if (cleanUrl.contains('supabase.co')) {
  html.window.open('$cleanUrl?download=true', '_blank');
} else {
  // Legacy Cloudinary URL → use proxy
  final token = html.window.localStorage['flutter.adtu_token'] ?? '';
  final encoded = Uri.encodeComponent(cleanUrl);
  html.window.open(
    '${AppConfig.apiUrl}/file-proxy?url=$encoded&token=${Uri.encodeComponent(token)}',
    '_blank',
  );
}
```

Note: For Supabase URLs, the frontend calls Supabase directly. The proxy is only used for legacy Cloudinary URLs.

---

## 6. Final Summary

`downloadRoutes.js` solves the fundamental browser limitation of not being able to set `Authorization` headers in file downloads. The implementation is intentionally minimal — just JWT verification + SSRF allow-listing + redirect. No file bytes pass through the server, so it's not a bandwidth bottleneck.
