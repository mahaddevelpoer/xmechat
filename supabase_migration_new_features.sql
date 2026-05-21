-- ── 5. E2E Encryption Public Key ──────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS public_key TEXT DEFAULT '';

-- ── 6. Voice Notes Bucket Public Read Policy ─────────────
-- Run ONLY if the voice-notes bucket already exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'voice-notes'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM storage.policies
      WHERE bucket_id = 'voice-notes' AND name = 'Public read voice notes'
    ) THEN
      CREATE POLICY "Public read voice notes"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'voice-notes');
    END IF;
  END IF;
END $$;

