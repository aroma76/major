const express = require('express');
const router  = express.Router();
const jwt     = require('jsonwebtoken');

/**
 * GET /api/file-proxy?url=<encoded_url>&token=<jwt>
 *
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

