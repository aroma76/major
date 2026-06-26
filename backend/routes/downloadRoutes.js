const express = require('express');
const router  = express.Router();
const jwt     = require('jsonwebtoken');
const path    = require('path');
const fs      = require('fs');

/**
 * GET /api/file-proxy?url=<encoded_url>&token=<jwt>
 *
 * Download proxy for file storage (Supabase or local disk).
 * - Supabase files: redirects to the public URL with ?download=true
 * - Local files:    streams the file directly from disk
 *
 * Token accepted in query param so window.open() works synchronously
 * (preserves user gesture, bypasses popup blockers).
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

  // ── Supabase Storage files ────────────────────────────────────────────────
  if (url.includes('supabase.co')) {
    const cleanUrl = url.split('?')[0];
    return res.redirect(`${cleanUrl}?download=true`);
  }

  // ── Local disk files ──────────────────────────────────────────────────────
  // URL format: http://localhost:5000/api/uploads/edusync/<filename>
  if (url.includes('/api/uploads/')) {
    const filename  = path.basename(url.split('?')[0]);
    const filePath  = path.join(__dirname, '..', 'uploads', 'edusync', filename);

    if (!fs.existsSync(filePath)) {
      return res.status(404).send('File not found');
    }

    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.sendFile(filePath);
  }

  // Unknown storage provider — reject
  return res.status(400).send('Unsupported file source');
});

/**
 * GET /api/uploads/edusync/:filename
 *
 * Serves locally stored files (used when STORAGE_PROVIDER=local).
 * This mirrors how Supabase public URLs work — no auth required to VIEW,
 * but the file-proxy above enforces auth for downloads.
 */
router.get('/uploads/edusync/:filename', (req, res) => {
  const filename = path.basename(req.params.filename); // prevent path traversal
  const filePath = path.join(__dirname, '..', 'uploads', 'edusync', filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ success: false, message: 'File not found' });
  }

  res.sendFile(filePath);
});

module.exports = router;
