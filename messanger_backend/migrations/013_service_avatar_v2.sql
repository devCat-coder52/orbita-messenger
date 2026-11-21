-- Актуальный аватар сервисного аккаунта Orbita.
--
-- Имя файла версионировано: клиент кеширует изображение по URL, и если оставить
-- прежний путь 'uploads/orbita.png', у уже установленных приложений останется
-- старая картинка из кэша. Файл кладётся в uploads при старте бэкенда
-- (см. ChatService.ensureServiceUser).
UPDATE user_info
SET avatar_url = 'uploads/orbita-2.png'
WHERE user_id = -1;
