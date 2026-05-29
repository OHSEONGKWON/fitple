-- 후기/온도 시스템

CREATE TABLE IF NOT EXISTS public.user_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gathering_id text NOT NULL,
  reviewer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  positive_tags text[] NOT NULL DEFAULT '{}',
  negative_tags text[] NOT NULL DEFAULT '{}',
  comment text,
  temperature_delta numeric(4,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_reviews_unique UNIQUE (gathering_id, reviewer_id, reviewee_id),
  CONSTRAINT user_reviews_no_self CHECK (reviewer_id <> reviewee_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reviews_gathering
ON public.user_reviews (gathering_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewee
ON public.user_reviews (reviewee_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewer
ON public.user_reviews (reviewer_id, created_at DESC);

ALTER TABLE public.user_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reviews_select ON public.user_reviews;
CREATE POLICY reviews_select ON public.user_reviews
  FOR SELECT USING (true);

DROP POLICY IF EXISTS reviews_insert ON public.user_reviews;
CREATE POLICY reviews_insert ON public.user_reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id AND reviewer_id <> reviewee_id);

DROP POLICY IF EXISTS reviews_delete ON public.user_reviews;
CREATE POLICY reviews_delete ON public.user_reviews
  FOR DELETE USING (auth.uid() = reviewer_id);

CREATE TABLE IF NOT EXISTS public.user_temperature (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  temperature numeric(5,1) NOT NULL DEFAULT 36.5,
  review_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_temperature_range CHECK (temperature BETWEEN 0 AND 100)
);

ALTER TABLE public.user_temperature ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS temp_select ON public.user_temperature;
CREATE POLICY temp_select ON public.user_temperature
  FOR SELECT USING (true);

DROP POLICY IF EXISTS temp_insert ON public.user_temperature;
CREATE POLICY temp_insert ON public.user_temperature
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS temp_update ON public.user_temperature;
CREATE POLICY temp_update ON public.user_temperature
  FOR UPDATE USING (true);
