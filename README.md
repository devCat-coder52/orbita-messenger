# Orbita Messenger

Монорепозиторий мессенджера: Flutter-клиент и Node.js-бэкенд. Обмен сообщениями
в реальном времени через Socket.IO, сквозное шифрование на клиенте,
push-уведомления через Firebase Cloud Messaging, хранение в PostgreSQL.

```
messanger_app/      Flutter-клиент (Android, iOS, Windows, Linux, Web)
messanger_backend/  Node.js API + Socket.IO
  db/schema.sql     схема для чистой базы
  migrations/       инкрементальные миграции
  tests/            интеграционные тесты (node:test)
```

## Стек

| Часть | Технологии |
|---|---|
| Клиент | Flutter, Dart, socket_io_client, Dio, sqflite (кэш), pointycastle (E2E) |
| Сервер | Node.js 22+, Express 5, Socket.IO 4, pg, winston |
| Хранилище | PostgreSQL 14+, Redis (коды подтверждения и cooldown) |
| Уведомления | Firebase Cloud Messaging |

## Быстрый старт через Docker

Нужен только Docker. Схема БД применяется автоматически, миграции — при старте
контейнера.

```bash
# 1. Секрет JWT обязателен (32+ символа), остальное имеет значения по умолчанию
echo "JWT_SECRET=$(openssl rand -hex 32)" > .env

# 2. Поднять стек
docker compose up --build

# 3. Проверить
curl http://localhost:3000/health
```

Для push-уведомлений положите `serviceAccountKey.json` в `messanger_backend/`
и раскомментируйте соответствующий volume в `docker-compose.yml`.

## Локальный запуск

Требования: Node.js 22+, PostgreSQL, Redis, Flutter SDK.

### Бэкенд

```bash
cd messanger_backend
cp .env.example .env      # заполните DB_*, JWT_SECRET, SMTP_*, REDIS_URL
npm ci
npm run migrate           # применить миграции (идемпотентно)
npm run cleanup:uploads   # сухой прогон уборки uploads (с --delete удаляет)
npm run dev               # nodemon, http://localhost:3000
```

Для чистой базы:

```bash
psql -U postgres -d orbita -f db/schema.sql
npm run migrate
```

### Клиент

```bash
cd messanger_app
# .env не хранится в git, создайте вручную:
#   BASE_URL=http://<адрес-сервера>:3000
#   SOCKET_URL=http://<адрес-сервера>:3000
#   BASE_URL_API=${BASE_URL}/api
flutter pub get
flutter run
```

`BASE_URL` должен быть доступен с телефона (не `localhost`, если запускаете на
устройстве). Для Android-эмулятора используйте `http://10.0.2.2:3000`.

## Переменные окружения (бэкенд)

Полный список — в `messanger_backend/.env.example`. Ключевые:

| Переменная | Зачем |
|---|---|
| `JWT_SECRET` | Подпись токенов. В production обязателен, 32+ символа, иначе сервер не стартует |
| `DB_*` | Подключение к PostgreSQL |
| `REDIS_URL` | Коды подтверждения email и cooldown отправки |
| `SMTP_*` | Отправка кодов подтверждения |
| `ALLOWED_ORIGINS` | CORS-allowlist, список через запятую |
| `PUBLIC_BASE_URL` | Публичный адрес API: нужен для картинок в push (FCM не принимает относительные URL) |
| `FIREBASE_PROJECT_ID` | Включает Firebase Admin, если рядом лежит `serviceAccountKey.json` |

## Тесты

```bash
# Бэкенд: интеграционные тесты против живой PostgreSQL и Redis
cd messanger_backend
npm test

# Клиент
cd messanger_app
flutter analyze
flutter test
```

Тесты бэкенда поднимают сервер отдельным процессом, работают с реальными
PostgreSQL и Redis и удаляют за собой данные с префиксом `zztest`.
Нужны запущенные зависимости и применённые миграции.

CI (`.github/workflows/ci.yml`) прогоняет на каждый push и PR: миграции,
`npm test` для бэкенда и `flutter analyze` + `flutter test` для клиента.

## Миграции

```bash
npm run migrate          # применить недостающие
npm run migrate:status   # показать состояние
```

Миграции — обычные `.sql` файлы в `messanger_backend/migrations/`, применяются
по имени в своей транзакции и записываются в таблицу `schema_migrations`.
Новый файл достаточно добавить в папку.

## Известные ограничения текущей беты

- Приватный ключ E2E хранится в `SharedPreferences` — до публичного релиза
  нужно перевести на `flutter_secure_storage`.
- Вложения (`/uploads`) раздаются по прямой ссылке без авторизации: любой, кто
  знает URL, получит файл. Медиа не шифруется E2E.
- Один инстанс: socket.io работает без Redis-адаптера, горизонтальное
  масштабирование пока не поддерживается.
- Групповые чаты, звонки, реакции и мультиустройство не реализованы.
