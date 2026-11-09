-- Сервисный аккаунт Orbita (id = -1): приветственный чат при регистрации.
-- В поиске и «Новом чате» не показывается (id < 1).
INSERT INTO users (id, login, email, password)
VALUES (-1, 'orbita', 'orbita@local', '!')
ON CONFLICT DO NOTHING;

INSERT INTO user_info (user_id, nick_name, bio)
VALUES (-1, 'Orbita', 'Сервисный аккаунт')
ON CONFLICT DO NOTHING;
