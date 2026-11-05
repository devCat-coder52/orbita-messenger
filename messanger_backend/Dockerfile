# Сборка бэкенда Orbita Messenger.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

# Сначала только манифесты: слой зависимостей кешируется отдельно от кода.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

# Папка для вложений должна существовать и быть доступной на запись.
RUN mkdir -p uploads/messages/images uploads/messages/files uploads/messages/voices

EXPOSE 3000

# Миграции идемпотентны, поэтому применяем их при старте контейнера.
CMD ["sh", "-c", "node scripts/migrate.js && node server.js"]
