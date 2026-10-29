-- ============================================================
-- Orbita Messenger — схема базы данных (PostgreSQL)
-- Применение: psql -U <user> -d <dbname> -f db/schema.sql
-- Идемпотентно: повторный запуск безопасен (IF NOT EXISTS).
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
  id           BIGSERIAL PRIMARY KEY,
  login        VARCHAR(25) NOT NULL UNIQUE,
  email        VARCHAR(255) NOT NULL UNIQUE,
  password     VARCHAR(255) NOT NULL,             -- bcrypt hash
  public_key   TEXT,                              -- публичный ключ E2E (v2:...)
  fcm_token    TEXT,                              -- токен Firebase Cloud Messaging
  is_online    BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen    TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_info (
  user_id    BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  nick_name  VARCHAR(25),
  avatar_url TEXT,
  location   VARCHAR(100),
  birth_date DATE,
  bio        VARCHAR(300),
  gender     CHAR(1) CHECK (gender IN ('М', 'Ж'))
);

CREATE TABLE IF NOT EXISTS chats (
  id          BIGSERIAL PRIMARY KEY,
  name        VARCHAR(255) NOT NULL DEFAULT '',
  creator_id  BIGINT REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_chats (
  chat_id    BIGINT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_pinned  BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (chat_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id                  BIGSERIAL PRIMARY KEY,
  chat_id             BIGINT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id           BIGINT REFERENCES users(id) ON DELETE SET NULL,
  content             TEXT,
  reply_to_message_id BIGINT REFERENCES messages(id) ON DELETE SET NULL,
  source_user_id      BIGINT REFERENCES users(id) ON DELETE SET NULL, -- автор оригинала при пересылке
  time_create         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  image_url           TEXT,
  file_url            TEXT,
  file_name           VARCHAR(255),
  file_size           BIGINT,
  voice_url           TEXT,
  voice_duration      INTEGER,
  status              VARCHAR(20) NOT NULL DEFAULT 'sent',   -- 'sent' | 'read'
  is_edited           BOOLEAN NOT NULL DEFAULT FALSE,
  is_encrypted        BOOLEAN NOT NULL DEFAULT FALSE,
  del_for_user_id     BIGINT REFERENCES users(id) ON DELETE CASCADE
);

-- Индексы под горячие запросы (список чатов, история сообщений, счётчики непрочитанного)
CREATE INDEX IF NOT EXISTS idx_messages_chat_time   ON messages (chat_id, time_create DESC);
CREATE INDEX IF NOT EXISTS idx_messages_del_for     ON messages (del_for_user_id);
CREATE INDEX IF NOT EXISTS idx_messages_status      ON messages (chat_id, status);
CREATE INDEX IF NOT EXISTS idx_user_chats_user      ON user_chats (user_id);
CREATE INDEX IF NOT EXISTS idx_users_login          ON users (login);
CREATE INDEX IF NOT EXISTS idx_users_email          ON users (email);
