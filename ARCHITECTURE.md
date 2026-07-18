# UPhone — Архитектура мессенджера

## Анализ вариантов архитектуры

### Вариант 1: Микросервисная архитектура

| Компонент | Технология |
|-----------|------------|
| API Gateway | Go (Chi/Echo) |
| Auth Service | Go |
| Chat Service | Go |
| Media Service | Go (Pion WebRTC) |
| Notification Service | Go |
| Search Service | Go |
| File Storage | Go + MinIO |

**Плюсы:** Независимое масштабирование, изоляция отказов, технологическая гибкость.
**Минусы:** Сложная оркестрация, сетевая задержка между сервисами, больше инфраструктуры.

### Вариант 2: Модульный монолит с event-driven

**Плюсы:** Простой деплой, легче отладка, меньше инфраструктуры.
**Минусы:** Сложнее масштабировать отдельные компоненты, единичная точка отказа.

### Вариант 3: Гибридная архитектура (РЕКОМЕНДУЕМЫЙ)

Единый бинарный файл с внутренней модульной структурой, внешние зависимости только на критических путях:

```
┌─────────────────────────────────────────────────┐
│                   UPhone Server                  │
├─────────────┬──────────────┬────────────────────┤
│  API Module │  WS Gateway  │   Media Module     │
│  (REST)     │  (real-time) │   (WebRTC SFU)     │
├─────────────┴──────────────┴────────────────────┤
│              Core Business Logic                 │
├─────────────────────────────────────────────────┤
│  Auth │ Chat │ Users │ Files │ Notifications     │
├─────────────────────────────────────────────────┤
│              Infrastructure Layer                │
├──────────┬──────────┬──────────┬────────────────┤
│PostgreSQL│  Redis   │  MinIO   │ NATS JetStream │
└──────────┴──────────┴──────────┴────────────────┘
```

---

## Обоснование выбора технологий

### Сервер: Go (Golang)

| Критерий | Обоснование |
|----------|-------------|
| Производительность | Компилируется в нативный код, ~C-level скорость |
| Конкурентность | Goroutines — дешёвые потоки, десятки тысяч WS-соединений |
| Деплой | Один бинарник, zero dependencies |
| WebRTC | Pion — зрелая Go-библиотека, ion-sfu для SFU |
| Экосистема | gRPC, WebSocket, JWT, bcrypt — всё в Go |
| Использование в индустрии | Discord (начинал с Go), Docker, Kubernetes, Telegram-боты |

### Клиент: Flutter

| Критерий | Обоснование |
|----------|-------------|
| Кроссплатформенность | Windows, Linux, Android, Web из одного кода |
| Производительность | Skia/Impeller рендеринг, near-native |
| Material Design 3 | Встроенные виджеты MD3, theming |
| WebRTC | `flutter_webrtc` пакет, зрелый |
| Архитектура | Riverpod + Freezed для чистой архитектуры |

### База данных: PostgreSQL 16

| Критерий | Обоснование |
|----------|-------------|
| ACID | Гарантия целостности сообщений |
| JSONB | Гибкая схема для метаданных сообщений |
| Full-text search | Встроенный поиск по сообщениям |
| Репликация | Streaming replication для отказоустойчивости |
| Расширения | pg_trgm для нечёткого поиска |

### Кеш: Redis 7

| Критерий | Обоснование |
|----------|-------------|
| Сессии | Хранение JWT refresh-токенов |
| Online-статус | Pub/Sub для статусов пользователей |
| Rate Limiting | Алгоритм token bucket |
| Кеш профилей | Горячие данные пользователей |
| Очереди | BullMQ для фоновых задач |

### Файловое хранилище: MinIO

| Критерий | Обоснование |
|----------|-------------|
| S3-совместимость | Лёгкая миграция на AWS S3 |
| Self-hosted | Полный контроль над данными |
| Erasure coding | Долговечность данных |
| Производительность | Высокая пропускная способность |

### Очередь сообщений: NATS JetStream

| Критерий | Обоснование |
|----------|-------------|
| Простота | Один бинарник, minimal config |
| Производительность | Миллионы сообщений/сек |
| Кластеризация | Встроенная поддержка |
| Stream processing | Гарантия доставки сообщений |

### WebRTC: Pion + custom SFU

| Критерий | Обоснование |
|----------|-------------|
| Pion | Зрелая Go-библиотека WebRTC |
| SFU | Selective Forwarding Unit для групповых звонков |
| Контроль | Полный контроль над медиа-пайплайном |
| STUN/TURN | cotURNServer (отдельный контейнер) |

---

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
│   │       └── main.go
│   ├── internal/
│   │   ├── config/                  # Конфигурация
│   │   ├── auth/                    # Аутентификация
│   │   ├── chat/                    # Бизнес-логика чатов
│   │   ├── users/                   # Управление пользователями
│   │   ├── files/                   # Загрузка файлов
│   │   ├── notifications/           # Уведомления
│   │   ├── media/                   # WebRTC медиа-сервер
│   │   ├── gateway/                 # WebSocket шлюз
│   │   └── infrastructure/
│   │       ├── database/            # PostgreSQL
│   │       ├── cache/               # Redis
│   │       ├── storage/             # MinIO
│   │       ├── queue/               # NATS
│   │       └── search/              # Поиск
│   ├── migrations/                  # SQL миграции
│   ├── api/                         # REST API handlers
│   ├── go.mod
│   └── go.sum
│
├── shared/                          # Общие типы (protobuf)
│   └── proto/
│       ├── auth.proto
│       ├── chat.proto
│       ├── user.proto
│       └── media.proto
│
├── docker/                          # Docker конфигурация
│   ├── Dockerfile.server
│   ├── Dockerfile.client
│   └── docker-compose.yml
│
├── infrastructure/                  # Инфраструктура
│   ├── nginx/
│   ├── coturn/
│   └── monitoring/
│
├── docs/                            # Документация
│   ├── architecture.md
│   ├── api.md
│   └── diagrams/
│
└── scripts/                         # Скрипты
    ├── setup.sh
    ├── migrate.sh
    └── deploy.sh
```

---

## API Endpoints (основные)

```
POST   /api/v1/auth/register
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout

GET    /api/v1/users/me
PUT    /api/v1/users/me
GET    /api/v1/users/search?q=
GET    /api/v1/users/:id

POST   /api/v1/chats
GET    /api/v1/chats
GET    /api/v1/chats/:id
POST   /api/v1/chats/:id/messages
GET    /api/v1/chats/:id/messages
PUT    /api/v1/chats/:id/messages/:msgId
DELETE /api/v1/chats/:id/messages/:msgId
POST   /api/v1/chats/:id/messages/:msgId/react

POST   /api/v1/files/upload
GET    /api/v1/files/:id

WS     /ws?token=                 # WebSocket для real-time
```

---

## Протокол WebSocket (JSON)

```json
// Клиент → Сервер
{"type": "message.send", "chatId": "123", "content": "Hello", "replyTo": null}
{"type": "typing.start", "chatId": "123"}
{"type": "message.read", "chatId": "123", "msgId": "456"}

// Сервер → Клиент
{"type": "message.new", "chatId": "123", "msg": {...}}
{"type": "user.online", "userId": "789"}
{"type": "message.reaction", "chatId": "123", "msgId": "456", "emoji": "👍"}
```

---

## Этапы разработки

| # | Этап | Описание | Результат |
|---|------|----------|-----------|
| 1 | **Инфраструктура** | Docker Compose, PostgreSQL, Redis, MinIO, NATS | Рабочая инфраструктура |
| 2 | **Auth Module** | Регистрация, вход, JWT, профиль | Авторизованные пользователи |
| 3 | **Chat Core** | Личные сообщения, WebSocket, история | Текстовый чат |
| 4 | **Группы и Каналы** | Групповые чаты, каналы, участники | Групповое общение |
| 5 | **Файлы** | Загрузка/отправка изображений, видео, документов | Медиа-контент |
| 6 | **UI Клиент** | Flutter: авторизация, чаты, контакты | Рабочий клиент |
| 7 | **Голосовые сообщения** | Запись и воспроизведение аудио | Голосовые сообщения |
| 8 | **Реакции и Уведомления** | Emoji реакции, пуш-уведомления | Интерактивность |
| 9 | **WebRTC Звонки** | Личные и групповые звонки | Аудио/видео связь |
| 10 | **Поиск и Настройки** | Поиск по истории, настройки профиля | Полный функционал |
| 11 | **CI/CD и Мониторинг** | GitHub Actions, Prometheus, Grafana | Продакшн-готовность |
