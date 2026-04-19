-- Add status column to blogs for staging workflow
ALTER TABLE public.blogs 
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'published';

-- Migrate existing data
UPDATE public.blogs SET status = 'published' WHERE is_published = true;
UPDATE public.blogs SET status = 'draft'     WHERE is_published = false;

-- Constraint to keep values clean
ALTER TABLE public.blogs 
  ADD CONSTRAINT IF NOT EXISTS blogs_status_check 
  CHECK (status IN ('draft', 'staging', 'published'));

-- Index for fast filtering
CREATE INDEX IF NOT EXISTS idx_blogs_status ON public.blogs (status);
