const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY, // service_role key: full storage access
);

const BUCKET = 'files';

/**
 * Ensures the 'files' storage bucket exists and is public.
 * Called once at server startup — safe to call multiple times.
 */
async function ensureBucket() {
  const { error } = await supabase.storage.createBucket(BUCKET, {
    public: true,
    allowedMimeTypes: null, // allow all
    fileSizeLimit: 52428800, // 50 MB
  });
  // Ignore "already exists" error
  if (error && !error.message.includes('already exists')) {
    console.warn('[Supabase] Could not create bucket:', error.message);
  } else {
    console.log(`[Supabase] Storage bucket "${BUCKET}" ready.`);
  }
}

module.exports = { supabase, BUCKET, ensureBucket };
