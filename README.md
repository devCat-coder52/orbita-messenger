# Orbita Messenger

## Описание
Монорепозиторий мессенджера с Flutter-клиентом и Node.js бэкендом. Реализует обмен сообщениями в реальном времени через Socket.IO, Push-уведомления и отслеживание статуса пользователей.

## Технологии
- **Flutter, Dart, Socket.IO Client, Dio** (Клиент)
- **Node.js, Express, Socket.IO** (Сервер)
- **Firebase Cloud Messaging (FCM)** (Уведомления)
- **PostgreSQL** (Хранение)

## Установка и запуск
### Клонирование
```bash
git clone https://github.com/devCat-coder52/orbita-messenger.git
```
### Бэкенд
```bash
cd messanger_backend
npm install
npm run dev
```
### Фронтенд
```bash
cd messanger_app
flutter pub get
flutter run
```
