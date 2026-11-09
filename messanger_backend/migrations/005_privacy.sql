-- Приватность профиля: показывать ли другим «в сети» и «был(а) недавно».
ALTER TABLE users ADD COLUMN IF NOT EXISTS show_online BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS show_last_seen BOOLEAN NOT NULL DEFAULT TRUE;
