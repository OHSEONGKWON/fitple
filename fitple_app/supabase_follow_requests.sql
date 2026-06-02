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

-- 팔로우 요청 수락 시 대상 유저(target)가 follows 행을 생성할 수 있도록 허용
-- (요청 발신자(requester)가 follower, 대상(target)이 following)
DROP POLICY IF EXISTS "follows_insert_by_request_target" ON follows;

CREATE POLICY "follows_insert_by_request_target" ON follows
  FOR INSERT WITH CHECK (
    auth.uid() = following_id
    AND follower_id != following_id
    AND EXISTS (
      SELECT 1
      FROM follow_requests fr
      WHERE fr.requester_id = follower_id
        AND fr.target_id = following_id
    )
  );
