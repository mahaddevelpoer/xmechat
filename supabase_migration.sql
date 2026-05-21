-- Add unique constraint for reactions table (needed for addReaction to work)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_reactions_message_user 
  ON public.reactions(message_id, user_id);

-- Add ringtone_url column to users table (for custom ringtone storage)
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS ringtone_url varchar DEFAULT '';

-- Add status privacy setting
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS status_privacy varchar DEFAULT 'everyone';
-- values: 'everyone', 'contacts', 'nobody'
