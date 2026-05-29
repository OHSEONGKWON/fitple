-- follows 테이블에 닉네임 컬럼 추가 (목록 표시용)
ALTER TABLE follows
  ADD COLUMN IF NOT EXISTS follower_nickname TEXT,
  ADD COLUMN IF NOT EXISTS following_nickname TEXT;

-- 팔로우 요청 테이블 (비공개 계정용)
CREATE TABLE IF NOT EXISTS follow_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requester_nickname TEXT,
  target_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(requester_id, target_id)
);

ALTER TABLE follow_requests ENABLE ROW LEVEL SECURITY;

-- 본인이 보낸/받은 요청만 조회 가능
CREATE POLICY "follow_requests_select" ON follow_requests
  FOR SELECT USING (
    auth.uid() = requester_id OR auth.uid() = target_id
  );

-- 로그인 유저가 요청 보내기 가능 (자기 자신 제외)
CREATE POLICY "follow_requests_insert" ON follow_requests
  FOR INSERT WITH CHECK (
    auth.uid() = requester_id AND requester_id != target_id
  );

-- 요청 취소(본인) 또는 수락/거절(대상) 모두 삭제로 처리
CREATE POLICY "follow_requests_delete" ON follow_requests
  FOR DELETE USING (
    auth.uid() = requester_id OR auth.uid() = target_id
  );
