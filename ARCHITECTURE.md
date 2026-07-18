# UPhone — Архитектура мессенджера

## Конфигурация

- ~10 одновременных пользователей
- Один Go-сервер, один Flutter-клиент
- Без микросервисов и лишней инфраструктуры

## Архитектура

```
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
│  PostgreSQL  │  Локальная FS (файлы)   │
└──────────────┴──────────────────────────┘
```

## Стек технологий

### Сервер: Go

| Компонент | Решение | Обоснование |
|-----------|---------|-------------|
| HTTP | chi router | Лёгкий, stdlib-compatible |
| WebSocket | gorilla/websocket | Зрелая библиотека |
| WebRTC | Pion | Зрелая Go-библиотека, P2P для 1:1 |
| БД | PostgreSQL 16 | ACID, JSONB, full-text search |
| Файлы | Локальная FS | ~10 пользователей, einfach |
| Авторизация | JWT (access + refresh) | Stateless, простота |
| Пароли | bcrypt | Стандарт безопасности |

### Клиент: Flutter

| Компонент | Решение | Обоснование |
|-----------|---------|-------------|
| Платформы | Windows, Linux, Android, Web | Один код |
| Архитектура | Riverpod + Freezed | Чистая архитектура |
| UI | Material Design 3 | Современный дизайн |
| WebRTC | flutter_webrtc | Зрелый пакет |
| Сеть | dio + web_socket_channel | HTTP + WS |
| Локальная БД | drift (SQLite) | Офлайн-кеш |

### Что НЕ используется

| Компонент | Почему исключён |
|-----------|-----------------|
| Redis | In-memory кеш в Go, ~10 пользователей |
| NATS | WebSocket hub напрямую |
| MinIO | Локальная ФС |
| Микросервисы | Один бинарник |
| SFU | P2P для 1:1, mesh для групп |
| Rate Limiting | ~10 пользователей |
| Nginx | Go слушает напрямую (development) |

## Структура проекта

```
uphone/
├── client/                          # Flutter клиент
│   ├── lib/
│   │   ├── core/                    # Ядро приложения
│   │   │   ├── config/              # Конфигурация
│   │   │   ├── di/                  # Dependency Injection
│   │   │   ├── network/             # HTTP/WS клиенты
│   │   │   ├── storage/             # Локальное хранилище
│   │   │   └── theme/               # Темы (светлая/тёмная)
│   │   ├── features/                # Модули по фичам
│   │   │   ├── auth/                # Авторизация
│   │   │   │   ├── data/
│   │   │   │   ├── domain/
│   │   │   │   └── presentation/
│   │   │   ├── chat/                # Чаты
│   │   │   ├── contacts/            # Контакты
│   │   │   ├── calls/               # Звонки
│   │   │   ├── profile/             # Профиль
│   │   │   └── settings/            # Настройки
│   │   ├── shared/                  # Общие виджеты
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── analysis_options.yaml
│
├── server/                          # Go сервер
│   ├── cmd/
│   │   └── server/
│   │       └── main.go              # Точка входа
│   ├── internal/
│   │   ├── config/                  # Конфигурация
│   │   ├── auth/                    # Аутентификация (JWT, bcrypt)
│   │   ├── chat/                    # Бизнес-логика чатов
│   │   │   ├── handler.go           # HTTP handlers
│   │   │   ├── service.go           # Бизнес-логика
│   │   │   ├── repository.go        # Работа с БД
│   │   │   └── ws_hub.go            # WebSocket хаб
│   │   ├── users/                   # Пользователи
│   │   ├── files/                   # Загрузка файлов
│   │   ├── media/                   # WebRTC (P2P)
│   │   └── infrastructure/
│   │       ├── database/            # PostgreSQL
│   │       └── storage/             # Локальная ФС
│   ├── migrations/                  # SQL миграции
│   │   └── 001_init.sql
│   ├── go.mod
│   └── go.sum
│
├── docker/
│   ├── Dockerfile.server
│   └── docker-compose.yml           # PostgreSQL + сервер
│
├── docs/
│   ├── ARCHITECTURE.md              # Этот файл
│   └── api.md                       # Описание API
│
├── .gitignore
└── README.md
```

## API Endpoints

### Auth
```
POST   /api/v1/auth/register        # Регистрация
POST   /api/v1/auth/login           # Вход (access + refresh токены)
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
POST   /api/v1/chats                # Создать чат (личный/групповой)
GET    /api/v1/chats                # Список чатов
GET    /api/v1/chats/:id            # Информация о чате
PUT    /api/v1/chats/:id            # Обновить чат
DELETE /api/v1/chats/:id            # Удалить чат
```

### Messages
```
POST   /api/v1/chats/:id/messages           # Отправить сообщение
GET    /api/v1/chats/:id/messages           # История (пагинация)
PUT    /api/v1/chats/:id/messages/:msgId     # Редактировать
DELETE /api/v1/chats/:id/messages/:msgId     # Удалить
POST   /api/v1/chats/:id/messages/:msgId/react  # Реакция
POST   /api/v1/chats/:id/messages/:msgId/pin    # Закрепить
```

### Files
```
POST   /api/v1/files/upload          # Загрузить файл
GET    /api/v1/files/:id             # Скачать файл
```

### WebSocket
```
WS     /ws?token=                    # Real-time соединение
```

## WebSocket Протокол

### Клиент → Сервер
```json
{"type": "message.send", "chatId": "123", "content": "Hello", "replyTo": null}
{"type": "typing.start", "chatId": "123"}
{"type": "typing.stop", "chatId": "123"}
{"type": "message.read", "chatId": "123", "msgId": "456"}
{"type": "presence.update", "status": "online"}
```

### Сервер → Клиент
```json
{"type": "message.new", "chatId": "123", "msg": {...}}
{"type": "message.updated", "chatId": "123", "msg": {...}}
{"type": "message.deleted", "chatId": "123", "msgId": "456"}
{"type": "typing.start", "chatId": "123", "userId": "789"}
{"type": "user.online", "userId": "789"}
{"type": "user.offline", "userId": "789"}
{"type": "message.reaction", "chatId": "123", "msgId": "456", "emoji": "👍", "userId": "789"}
```

## Database Schema (основные таблицы)

```sql
-- Пользователи
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(30) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100),
    avatar_url TEXT,
    status VARCHAR(20) DEFAULT 'offline',
    last_seen TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Чаты
CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL, -- 'personal', 'group', 'channel'
    name VARCHAR(100),
    description TEXT,
    avatar_url TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Участники чатов
CREATE TABLE chat_members (
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member', -- 'owner', 'admin', 'member'
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (chat_id, user_id)
);

-- Сообщения
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID REFERENCES chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id),
    content TEXT,
    type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'video', 'file', 'voice'
    file_url TEXT,
    reply_to UUID REFERENCES messages(id),
    is_pinned BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Реакции
CREATE TABLE reactions (
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id, emoji)
);

-- Индексы
CREATE INDEX idx_messages_chat_id ON messages(chat_id, created_at DESC);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_chat_members_user_id ON chat_members(user_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
```

## Этапы разработки

| # | Этап | Описание | Результат |
|---|------|----------|-----------|
| 1 | **Инфраструктура** | Docker Compose, PostgreSQL, Go проект | Рабочая среда |
| 2 | **Auth** | Регистрация, вход, JWT, профиль | Авторизация |
| 3 | **Chat Core** | Личные сообщения, WebSocket, история | Текстовый чат |
| 4 | **Группы и Каналы** | Групповые чаты, каналы, участники | Групповое общение |
| 5 | **Файлы** | Загрузка изображений, видео, документов | Медиа-контент |
| 6 | **UI Клиент** | Flutter: авторизация, чаты, контакты | Рабочий клиент |
| 7 | **Голосовые сообщения** | Запись и воспроизведение аудио | Голосовые сообщения |
| 8 | **Реакции и Уведомления** | Emoji реакции, уведомления | Интерактивность |
| 9 | **WebRTC Звонки** | Личные и групповые звонки | Аудио/видео связь |
| 10 | **Поиск и Настройки** | Поиск по истории, настройки | Полный функционал |
