# Деплой бэкенда на VPS

Инструкция для одного сервера: API, PostgreSQL, Redis и TLS на одной машине.
Хватает VPS на 1 vCPU / 1–2 ГБ ОЗУ (для беты на 3–10 человек — с запасом).

## 1. Что нужно до начала

- VPS с Ubuntu 24.04, root-доступ, оплата картой РФ или СБП.
- Адрес API. Либо купленный домен (`api.orbita.ru`), либо бесплатный
  поддомен на DuckDNS (`orbita.duckdns.org`) — для TLS годится и то и другое.
- DNS: A-запись `api` → IP сервера. Проверить: `nslookup api.orbita.ru`.

## 2. Подготовка сервера

```bash
# swap: на 1 ГБ без него сборка образа и миграции могут упасть по памяти
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Docker + compose
curl -fsSL https://get.docker.com | sh

# Файрвол: наружу только SSH, HTTP и HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 3. Запуск

```bash
git clone <адрес-репозитория> orbita && cd orbita

cp .env.prod.example .env.prod
nano .env.prod        # DOMAIN, DB_PASSWORD, JWT_SECRET, SMTP_*, ALLOWED_ORIGINS, PUBLIC_BASE_URL
chmod 600 .env.prod

docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

Первый запуск занимает несколько минут: собирается образ бэкенда, применяется
схема БД и миграции, Caddy выпускает сертификат.

## 4. Проверка

```bash
curl https://api.orbita.ru/health
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f caddy
```

Если Caddy не получил сертификат — почти всегда не сошлась DNS-запись или
закрыт 80-й порт. Сертификат выпускается только после того, как домен
уже указывает на сервер.

## 5. Push-уведомления

Положить `serviceAccountKey.json` из Firebase в `messanger_backend/` и
раскомментировать соответствующий volume в `docker-compose.prod.yml`,
затем `up -d`. Без файла сервер работает, но push не отправляет.

## 6. Обновление версии

```bash
git pull
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

Миграции применяются автоматически при старте контейнера.

## 7. Бэкап

```bash
# дамп базы
docker compose --env-file .env.prod -f docker-compose.prod.yml \
  exec -T postgres pg_dump -U postgres orbita | gzip > backup-$(date +%F).sql.gz

# вложения
tar czf uploads-$(date +%F).tar.gz messanger_backend/uploads
```

Поставить в cron на ночь и раз в неделю забирать архив к себе. `.env.prod`
и `serviceAccountKey.json` тоже сохранить в надёжном месте — без них
восстановление займёт лишний вечер.

## 8. Сборка APK под этот сервер

```bash
cd messanger_app
flutter build apk --release --split-per-abi \
  --dart-define=BASE_URL=https://api.orbita.ru \
  --dart-define=SOCKET_URL=https://api.orbita.ru
```

Готовые файлы — в `build/app/outputs/flutter-apk/`. Тестерам отправлять
`app-arm64-v8a-release.apk` (подходит для всех современных телефонов).

## 9. Вариант без VPS: туннель

Пока сервера нет, бету можно проверить бесплатно — бэкенд крутится на
ноутбуке, наружу его отдаёт Cloudflare Tunnel.

```powershell
# 1. зависимости локально
docker compose up -d

# 2. туннель (один раз установить: winget install Cloudflare.cloudflared)
cloudflared tunnel --url http://localhost:3000
```

`cloudflared` напечатает адрес вида `https://random-words.trycloudflare.com` —
это и есть публичный HTTPS-адрес API.

```powershell
cd messanger_app
flutter build apk --release `
  --dart-define=BASE_URL=https://random-words.trycloudflare.com `
  --dart-define=SOCKET_URL=https://random-words.trycloudflare.com
```

Ограничения: ноутбук должен быть включён, адрес меняется при каждом
перезапуске туннеля (значит, нужна пересборка APK), скорость зависит от
домашнего интернета. Для проверки «работает ли у других» — идеально,
для постоянной раздачи — нет.

