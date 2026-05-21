-- ── 5. E2E Encryption Public Key ──────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS public_key TEXT DEFAULT '';

