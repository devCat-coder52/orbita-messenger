-- Системные сообщения: центрированная плашка вместо пузыря.
-- Не шифруются, не редактируются и не пересылаются.
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_system BOOLEAN NOT NULL DEFAULT FALSE;
