-- Приводим внешние ключи к тому, что описано в db/schema.sql.
--
-- В живой БД они были созданы без ON DELETE действий, из-за чего:
--  * DELETE FROM chats падал, пока оставались строки в user_chats;
--  * удаление аккаунта падало, если у пользователя остались сообщения
--    в чате, где есть другие участники (sender_id NO ACTION);
--  * user_info вообще не ссылалась на users (сироты после удаления).
--
-- Миграция идемпотентна: DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT.

-- chats.creator_id -> SET NULL
ALTER TABLE chats DROP CONSTRAINT IF EXISTS chats_creator_id_fkey;
ALTER TABLE chats
  ADD CONSTRAINT chats_creator_id_fkey
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL;

-- messages.sender_id -> SET NULL (сообщения остаются в истории чата)
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;
ALTER TABLE messages
  ADD CONSTRAINT messages_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE SET NULL;

-- messages.source_user_id -> SET NULL (автор пересланного сообщения)
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_source_user_id_fkey;
ALTER TABLE messages
  ADD CONSTRAINT messages_source_user_id_fkey
  FOREIGN KEY (source_user_id) REFERENCES users(id) ON DELETE SET NULL;

-- user_chats: каскадное удаление вместе с чатом и пользователем
ALTER TABLE user_chats DROP CONSTRAINT IF EXISTS user_chats_chat_id_fkey;
ALTER TABLE user_chats
  ADD CONSTRAINT user_chats_chat_id_fkey
  FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE;

ALTER TABLE user_chats DROP CONSTRAINT IF EXISTS user_chats_user_id_fkey;
ALTER TABLE user_chats
  ADD CONSTRAINT user_chats_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- user_info: профиль удаляется вместе с пользователем.
-- Сначала убираем возможных сирот, иначе ADD CONSTRAINT не пройдёт валидацию.
DELETE FROM user_info WHERE user_id NOT IN (SELECT id FROM users);

ALTER TABLE user_info DROP CONSTRAINT IF EXISTS user_info_user_id_fkey;
ALTER TABLE user_info
  ADD CONSTRAINT user_info_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
