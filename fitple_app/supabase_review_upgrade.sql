-- 후기/평점 시스템

CREATE TABLE IF NOT EXISTS public.user_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gathering_id uuid NOT NULL,
  reviewer_id uuid NOT NULL,
  reviewee_id uuid NOT NULL,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_reviews_unique UNIQUE (gathering_id, reviewer_id, reviewee_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewee
ON public.user_reviews (reviewee_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewer
ON public.user_reviews (reviewer_id, created_at DESC);
