const express    = require('express');
const router     = express.Router();
const jwt        = require('jsonwebtoken');
const cloudinary = require('../config/cloudinary');

/**
 * GET /api/file-proxy?url=<encoded_cloudinary_url>&token=<jwt>
 *
 * Accepts a JWT via query param (so window.open() can call it synchronously,
 * preserving the browser user-gesture and avoiding popup blockers).
 *
 * Generates a signed Cloudinary URL and 302-redirects to it — the browser
 * follows the redirect and downloads/displays the file directly from
 * Cloudinary, so no file bytes pass through our server.
 */
router.get('/', async (req, res) => {
  const { url, token } = req.query;

  // ── Auth ────────────────────────────────────────────────────────────────
  if (!token) return res.status(401).send('Unauthorized');
  try {
    jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    return res.status(401).send('Invalid token');
  }

  // ── Validate URL ─────────────────────────────────────────────────────────
  if (!url || !url.includes('res.cloudinary.com')) {
    return res.status(400).send('Invalid URL');
  }

  // Parse resource_type and public_id from delivery URL.
  // e.g. https://res.cloudinary.com/{cloud}/{type}/upload/[v{n}/]{public_id}
  const match = url.match(
    /res\.cloudinary\.com\/[^/]+\/(image|raw|video)\/upload\/(?:(?:v\d+)\/)?(.+?)(\?|$)/
  );
  if (!match) return res.redirect(url); // unknown format — pass through

  const resourceType = match[1];
  const publicId     = decodeURIComponent(match[2].replace(/\/$/, ''));

  try {
    const signedUrl = cloudinary.url(publicId, {
      resource_type : resourceType,
      type          : 'upload',
      sign_url      : true,
      expires_at    : Math.floor(Date.now() / 1000) + 300, // 5 min
      // fl_attachment only for raw — image-type fl_attachment causes ERR_INVALID_RESPONSE
      ...(resourceType === 'raw' ? { flags: 'attachment' } : {}),
    });

    return res.redirect(signedUrl);
  } catch (err) {
    // Fallback: redirect to original URL
    return res.redirect(url);
  }
});

module.exports = router;
