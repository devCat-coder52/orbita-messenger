-- Сервисные чаты больше не закрепляются автоматически: снимаем закрепление
-- с уже созданных чатов Orbita у обычных пользователей.
UPDATE user_chats uc
SET is_pinned = FALSE
WHERE uc.user_id <> -1
  AND uc.chat_id IN (SELECT chat_id FROM user_chats WHERE user_id = -1);
