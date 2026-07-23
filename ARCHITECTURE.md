# UPhone — Архитектура мессенджера

## Конфигурация

- ~10 одновременных пользователей
- Один Go-сервер, один Flutter-клиент (Web — приоритет)
- Без микросервисов и лишней инфраструктуры

## Правила ветвления

- Каждая фича — отдельная ветка `feature/<name>` или `fix/<name>`
- Каждая фича покрывается тестами
- Мерж в `master` через `--no-ff`
- Прямые коммиты в `master` запрещены

## Архитектура

```
┌─────────────────────────────────────────┐
│              Apache2                    │
│    (reverse proxy + static files)       │
├──────────┬──────────────────────────────┤
│ /api/*   │  /ws  │  /* (static)         │
└────┬─────┴───┬───┴───────┬─────────────┘
     │         │           │
     ▼         ▼           ▼
┌─────────────────────────────────────────┐
│              UPhone Server              │
│              (Go, один бинарник)        │
├──────────┬──────────┬───────────────────┤
│ REST API │ WebSocket│   WebRTC (P2P)    │
├──────────┴──────────┴───────────────────┤
│         Business Logic (Go)             │
├─────────────────────────────────────────┤
│          Infrastructure Layer           │
├──────────────┬──────────────────────────┤
│   MariaDB   │  MinIO/S3 (файлы)         │
└──────────────┴──────────────────────────┘
```

## Стек технологий

### Сервер: Go

| Компонент | Решение | Обоснование |
|-----------|---------|-------------|
| HTTP | chi router v5 | Лёгкий, stdlib-compatible |
| WebSocket | gorilla/websocket | Зрелая библиотека |
| WebRTC | Сигналинг через WS | P2P для 1:1 |
| БД | MariaDB 11 | ACID, JSON, full-text, MySQL-совместимость |
| Файлы | MinIO/S3 (Docker) или локальная FS | S3-совместимое хранилище |
| Авторизация | JWT (access + refresh) | Stateless |
| Пароли | bcrypt | Стандарт безопасности |
| Google OAuth | google_sign_in + server verification | SSO |

### Клиент: Flutter

| Компонент | Решение | Обоснование |
|-----------|---------|-------------|
| Платформы | Web (приоритет), Android | Один код |
| Архитектура | Riverpod + Freezed | Чистая архитектура |
| UI | Material Design 3 | Современный дизайн |
| WebRTC | flutter_webrtc | Зрелый пакет |
| Сеть | dio + web_socket_channel | HTTP + WS |
| Роутинг | go_router | Declarative routing |

### Что НЕ используется

| Компонент | Почему исключён |
|-----------|-----------------|
| Redis | ~10 пользователей, in-memory в Go |
| NATS | WebSocket hub напрямую |
| Микросервисы | Один бинарник |
| SFU | P2P для 1:1 |
| Rate Limiting | ~10 пользователей |
| Docker (прод) | Прямой деплой на Ubuntu/Debian |

## Структура проекта

```
uphone/
├── client/                          # Flutter клиент
│   ├── lib/
│   │   ├── core/                    # Ядро приложения
│   │   │   ├── config/              # ServerConfig, AppConfig, RememberMe
│   │   │   ├── network/             # ApiClient (Dio), WsClient
│   │   │   ├── router/              # Go Router конфигурация
│   │   │   ├── theme/               # Темы (светлая/тёмная)
│   │   │   └── utils/               # Google Sign-In helpers
│   │   ├── features/                # Модули по фичам
│   │   │   ├── auth/                # Авторизация (JWT + Google OAuth)
│   │   │   ├── chat/                # Чаты, сообщения, WebSocket
│   │   │   ├── contacts/            # Контакты (CRUD, vCard/CSV)
│   │   │   └── calls/               # WebRTC звонки
│   │   ├── shared/                  # Модели (User, Chat, Contact)
│   │   └── main.dart
│   └── pubspec.yaml
│
├── server/                          # Go сервер
│   ├── cmd/server/main.go           # Точка входа
│   ├── internal/
│   │   ├── config/                  # Конфигурация (env vars)
│   │   ├── auth/                    # JWT, bcrypt, Google OAuth
│   │   ├── chat/                    # Чаты, сообщения, WebSocket хаб
│   │   ├── contacts/                # Контакты (CRUD, vCard, CSV)
│   │   ├── users/                   # Пользователи
│   │   ├── webrtc/                  # WebRTC сигналинг
│   │   ├── fcm/                     # Firebase Cloud Messaging
│   │   ├── admin/                   # Админ-панель
│   │   ├── storage/                 # S3/MinIO + LocalStorage
│   │   └── middleware/              # Auth, CORS
│   ├── migrations/                  # SQL миграции
│   │   ├── 001_init.sql
│   │   ├── 002_google_oauth.sql
│   │   ├── 003_contacts.sql
│   │   └── 004..007_fcm_token, call_logs
│   └── go.mod
│
├── deploy/                          # Развёртывание
│   ├── deploy.sh                    # Основной скрипт (bare-metal)
│   ├── uphone.env.example           # Шаблон конфига
│   ├── uphone.service               # Systemd unit
│   └── uphone.conf                  # Apache2 vhost
│
├── docker/                          # Docker Compose (локальная разработка)
│   ├── docker-compose.yml           # server + MariaDB + MinIO
│   └── Dockerfile.server
│
└── ARCHITECTURE.md
```

## API Endpoints

### Auth
```
POST   /api/v1/auth/register        # Регистрация
POST   /api/v1/auth/login           # Вход (access + refresh токены)
POST   /api/v1/auth/google          # Google OAuth (id_token)
POST   /api/v1/auth/refresh         # Обновление access токена
POST   /api/v1/auth/logout          # Выход
```

### Users
```
GET    /api/v1/users/me             # Текущий пользователь
PUT    /api/v1/users/me             # Обновить профиль
GET    /api/v1/users/search?q=      # Поиск пользователей
GET    /api/v1/users/:id            # Профиль пользователя
```

### Chats
```
POST   /api/v1/chats                # Создать чат (personal/group/channel)
GET    /api/v1/chats                # Список чатов
GET    /api/v1/chats/:id            # Информация о чате
PUT    /api/v1/chats/:id            # Обновить чат
DELETE /api/v1/chats/:id            # Удалить чат
```

### Members
```
GET    /api/v1/chats/:id/members              # Список участников
POST   /api/v1/chats/:id/members              # Добавить участника
DELETE /api/v1/chats/:id/members/:memberId    # Удалить участника
POST   /api/v1/chats/:id/leave                # Покинуть чат
```

### Messages
```
POST   /api/v1/chats/:id/messages              # Отправить сообщение
GET    /api/v1/chats/:id/messages              # История (пагинация)
PUT    /api/v1/chats/:id/messages/:msgId       # Редактировать
DELETE /api/v1/chats/:id/messages/:msgId       # Удалить
POST   /api/v1/chats/:id/messages/:msgId/react # Реакция
POST   /api/v1/chats/:id/messages/:msgId/forward # Переслать
GET    /api/v1/chats/:id/media                 # Медиа-файлы чата
POST   /api/v1/chats/:id/read                  # Отметить как прочитанное
```

### Contacts
```
GET    /api/v1/contacts?q=           # Список контактов (поиск)
POST   /api/v1/contacts              # Создать контакт
GET    /api/v1/contacts/:id          # Получить контакт
PUT    /api/v1/contacts/:id          # Обновить контакт
DELETE /api/v1/contacts/:id          # Удалить контакт
GET    /api/v1/contacts/export       # Экспорт (vcard|csv)
POST   /api/v1/contacts/import       # Импорт (vcard|csv)
```

### Upload / WebSocket
```
POST   /api/v1/upload               # Загрузить файл
WS     /ws?token=                   # Real-time соединение
```

## WebSocket Протокол

### Клиент → Сервер
```json
{"type": "message.send", "chatId": "123", "content": "Hello", "replyTo": null}
{"type": "typing.start", "chatId": "123"}
{"type": "typing.stop", "chatId": "123"}
{"type": "call-request", "call_id": "...", "to_user": "...", "payload": {"call_type": "video"}}
{"type": "call-accept", "call_id": "..."}
{"type": "call-reject", "call_id": "..."}
{"type": "call-end", "call_id": "..."}
{"type": "missed_call", "call_id": "...", "chat_id": "...", "from_user": "...", "call_type": "audio|video"}
```

### Сервер → Клиент
```json
{"type": "message.new", "payload": {...}}
{"type": "typing.start", "payload": {"userId": "...", "chatId": "..."}}
{"type": "typing.stop", "payload": {"userId": "...", "chatId": "..."}}
{"type": "call-request", "payload": {...}}
{"type": "call-accept", "payload": {...}}
{"type": "candidate", "payload": {...}}
{"type": "offer", "payload": {...}}
{"type": "answer", "payload": {...}}
```

## Database Schema (MariaDB)

Таблицы: `users`, `chats`, `chat_members`, `messages`, `reactions`, `contacts`, `call_logs`, `message_reads`, `fcm_tokens`

Миграции: `server/migrations/001_init.sql` .. `007_call_logs.sql`

Схема применяется автоматически при старте сервера (idempotent, `IF NOT EXISTS`).

## Этапы разработки

| # | Этап | Статус |
|---|------|--------|
| 1 | Инфраструктура (MariaDB, Go проект) | Готово |
| 2 | Auth (JWT, bcrypt, Google OAuth) | Готово |
| 3 | Chat Core (личные сообщения, WebSocket, история) | Готово |
| 4 | Группы и каналы (участники, roles) | Готово |
| 5 | Файлы (загрузка, изображения, видео, документы) | Готово |
| 6 | Flutter Web клиент | Готово |
| 7 | Голосовые сообщения | Готово |
| 8 | Реакции (emoji) | Готово |
| 9 | WebRTC звонки (аудио/видео) | Готово |
| 10 | Контакты (CRUD, vCard/CSV импорт/экспорт) | Готово |
| 11 | Remember Me (сохранение логина) | Готово |
| 12 | Боевое развёртывание (deploy script) | Готово |
| 13 | Push-уведомления (FCM, входящие звонки) | Готово |
| 14 | Пропущенные звонки (30с таймаут, call_logs, system message) | Готово |
| 15 | Настройки чатов (аватар, переименование, управление участниками) | Готово |
| 16 | MinIO/S3 хранилище (Docker + bare-metal) | Готово |
| 17 | Счётчик непрочитанных, автопрокрутка | Готово |
