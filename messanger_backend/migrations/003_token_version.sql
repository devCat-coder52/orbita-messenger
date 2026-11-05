-- Версия сессии пользователя.
--
-- Инкрементится при смене пароля: токены содержат версию (`v`) и сверяются
-- с этим значением, поэтому старые сессии перестают работать.
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0;
