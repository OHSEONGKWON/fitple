-- Chat feature upgrade for:
-- 1) last message preview/time
-- 2) realtime unread sync metadata
-- 5) reply
-- 6) image message
-- 8) search support (index)

ALTER TABLE public.chat_rooms
ADD COLUMN IF NOT EXISTS host_last_read_at timestamptz,
ADD COLUMN IF NOT EXISTS guest_last_read_at timestamptz,
ADD COLUMN IF NOT EXISTS host_last_seen_at timestamptz,
ADD COLUMN IF NOT EXISTS guest_last_seen_at timestamptz,
ADD COLUMN IF NOT EXISTS last_message_at timestamptz;

ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS message_type text DEFAULT 'text',
ADD COLUMN IF NOT EXISTS image_url text,
ADD COLUMN IF NOT EXISTS reply_to_message_id uuid,
ADD COLUMN IF NOT EXISTS reply_to_content text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_name = 'messages_reply_to_message_id_fkey'
      AND table_name = 'messages'
  ) THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_reply_to_message_id_fkey
      FOREIGN KEY (reply_to_message_id)
      REFERENCES public.messages(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_messages_room_created_at
ON public.messages (room_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_room_content_search
ON public.messages USING gin (to_tsvector('simple', coalesce(content, '')));

-- Storage bucket for chat image messages
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-images', 'chat-images', true)
ON CONFLICT (id) DO NOTHING;
