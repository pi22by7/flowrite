-- Required only when using the optional Supabase backend.
-- Retain deleted documents so offline devices can observe deletions.
ALTER TABLE public.user_files ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT FALSE;
