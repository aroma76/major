const express = require('express');
const router  = express.Router();
const jwt     = require('jsonwebtoken');

/**
 * GET /api/file-proxy?url=<encoded_url>&token=<jwt>
 *
 * Simple download proxy:
 *  - Supabase URLs  → redirect to `url?download=true` (public, no signing needed)
 *  - Cloudinary URLs (legacy) → redirect as-is (user can save from browser)
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

  // ── Route by storage provider ─────────────────────────────────────────────
  if (url.includes('supabase.co')) {
    // Supabase public bucket: ?download=true triggers Content-Disposition: attachment
    const cleanUrl = url.split('?')[0];
    return res.redirect(`${cleanUrl}?download=true`);
  }

  // Legacy Cloudinary URL — open as-is (best-effort)
  return res.redirect(url.split('?')[0]);
});

module.exports = router;
