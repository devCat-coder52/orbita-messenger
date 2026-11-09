-- Тихий режим чата: push по этому чату не отправляются.
ALTER TABLE user_chats ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT FALSE;
