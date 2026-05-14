const express  = require('express');
const router   = express.Router();
const cloudinary = require('../config/cloudinary');
const { protect } = require('../middleware/auth');

/**
 * GET /api/signed-download?fileUrl=<encoded_cloudinary_url>
 *
 * Generates a short-lived (1 h) signed Cloudinary URL so the client can
 * download raw files even when the account has "Restrict raw delivery"
 * enabled (which causes plain delivery URLs to return HTTP 401).
 *
 * Only Cloudinary URLs are accepted. Requires a valid JWT (protect).
 */
router.get('/', protect, (req, res) => {
  const { fileUrl } = req.query;

  if (!fileUrl || !fileUrl.includes('res.cloudinary.com')) {
    return res.status(400).json({ success: false, message: 'Invalid file URL' });
  }

  // Parse resource_type and public_id from the Cloudinary delivery URL.
  // Expected format:
  //   https://res.cloudinary.com/{cloud}/{resource_type}/upload/[transforms/][v{ver}/]{public_id}.{ext}
  const match = fileUrl.match(
    /res\.cloudinary\.com\/[^/]+\/(image|raw|video)\/upload\/(?:[^/]+\/)*?(?:v\d+\/)?(.+?)(\?|$)/
  );

  if (!match) {
    // Can't parse — return the original URL so the client can still try it
    return res.json({ success: true, url: fileUrl });
  }

  const resourceType  = match[1];                 // 'image' | 'raw' | 'video'
  const publicIdFull  = match[2].replace(/\/$/, ''); // includes folder + filename

  try {
    const expiresAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour

    const signedUrl = cloudinary.url(publicIdFull, {
      resource_type : resourceType,
      type          : 'upload',
      sign_url      : true,       // adds auth signature — bypasses 401 restriction
      expires_at    : expiresAt,
      flags         : 'attachment', // force browser download
    });

    res.json({ success: true, url: signedUrl });
  } catch (err) {
    // Fallback: send original URL — better than a 500
    res.json({ success: true, url: fileUrl });
  }
});

module.exports = router;
