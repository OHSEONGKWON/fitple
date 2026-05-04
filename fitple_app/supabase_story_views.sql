-- 스토리 조회 기록 테이블
CREATE TABLE IF NOT EXISTS story_views (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  viewer_nickname TEXT,
  viewed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(story_id, viewer_id)
);

ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;

-- 로그인한 유저는 조회 기록 추가 가능
CREATE POLICY "Users can insert views"
  ON story_views FOR INSERT
  TO authenticated
  WITH CHECK (viewer_id = auth.uid());

-- 모든 로그인 유저가 조회 기록 읽기 가능 (스토리 소유자 확인용)
CREATE POLICY "Authenticated users can read views"
  ON story_views FOR SELECT
  TO authenticated
  USING (true);
