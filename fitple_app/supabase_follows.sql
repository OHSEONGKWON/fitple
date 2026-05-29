-- follows 테이블
CREATE TABLE IF NOT EXISTS follows (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id)
);

-- RLS 활성화
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- 누구나 팔로우 수 조회 가능
CREATE POLICY "follows_select" ON follows
  FOR SELECT USING (true);

-- 로그인한 유저만 팔로우/언팔로우 가능 (자기 자신은 팔로우 불가)
CREATE POLICY "follows_insert" ON follows
  FOR INSERT WITH CHECK (
    auth.uid() = follower_id AND follower_id != following_id
  );

CREATE POLICY "follows_delete" ON follows
  FOR DELETE USING (auth.uid() = follower_id);
