# UPhone

Мультиплатформенный мессенджер: чаты, контакты, аудио/видео звонки (WebRTC, mesh P2P), обмен файлами, push-уведомления, пропущенные звонки, настройки чатов (аватар, переименование).

## Быстрый старт

### Требования

- Go 1.25+
- Flutter 3.x (stable)
- MariaDB 11+
- Apache2 (для прода) или напрямую Go сервер (для разработки)
- Firebase проект (для push-уведомлений на Android)
- Docker + Docker Compose (для локальной разработки)

### Локальная разработка

#### Docker (рекомендуется)

```bash
cd docker
docker compose up -d        # запуск server + MariaDB + MinIO
# Сервер: http://localhost:8080
# MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
```

Клиент:
```bash
cd client
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=WS_URL=ws://localhost:8080/ws
```

#### Без Docker

```bash
# Сервер
cd server
go mod tidy
# Запуск (предварительно создать БД и применить миграции)
DB_HOST=127.0.0.1 DB_PORT=3307 DB_USER=uphone DB_PASSWORD=uphone_secret \
  SERVER_PORT=8080 GOOGLE_CLIENT_ID=<your_id> FCM_CREDENTIALS=<path/to/firebase-adminsdk.json> \
  go run ./cmd/server

# Клиент (web)
cd client
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=WS_URL=ws://localhost:8080/ws

# Клиент (Android)
flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.18:8080 \
  --dart-define=WS_URL=ws://192.168.1.18:8080/ws
```

### Firebase (push-уведомления)

Для Android push-уведомлений (входящие звонки на заблокированном экране):

1. Создайте Firebase проект в [Firebase Console](https://console.firebase.google.com/)
2. Добавьте Android-приложение с package name `com.uphone.uphone_client`
3. Скачайте `google-services.json` → `client/android/app/google-services.json`
4. Скачайте Service Account JSON (Firebase → Settings → Service accounts → Generate new private key)
5. Положите JSON-ключ на сервер и укажите путь в `FCM_CREDENTIALS`

### Тесты

```bash
cd server
go test ./...
```

## Развёртывание на боевом сервере

Один скрипт — Ubuntu/Debian + MariaDB + Apache2:

```bash
git clone https://github.com/BlkDem/uphone.git
cd uphone

# По IP (без HTTPS)
sudo bash deploy/deploy.sh

# С доменом и HTTPS (Let's Encrypt)
sudo bash deploy/deploy.sh --domain=chat.example.com
```

Скрипт автоматически:
- Устанавливает Go, Flutter, MariaDB, Apache2, MinIO (объектное хранилище)
- Создаёт базу данных и пользователя
- Собирает Go сервер и Flutter web-клиент
- Настраивает systemd сервис и Apache2 (reverse proxy + WebSocket)
- Генерирует JWT секрет
- При `--domain` — получает SSL-сертификат Let's Encrypt, настраивает HTTPS + auto-renewal
- MinIO включён по умолчанию (отключить: `USE_MINIO=false`)

### Конфигурация

Конфиг: `/etc/uphone/uphone.env`

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `SERVER_PORT` | Порт сервера | `8080` |
| `DB_HOST` | Хост MariaDB | `localhost` |
| `DB_PORT` | Порт MariaDB | `3306` |
| `DB_USER` | Пользователь БД | `uphone` |
| `DB_PASSWORD` | Пароль БД | `uphone_secret` |
| `DB_NAME` | Имя БД | `uphone` |
| `JWT_SECRET` | Секрет JWT | `change-me-in-production` |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | — |
| `FCM_CREDENTIALS` | Путь к Firebase Service Account JSON | — |
| `UPLOAD_DIR` | Директория файлов (фолбэк) | `./uploads` |
| `UPLOAD_BASE_URL` | Базовый URL для файлов | `http://localhost:{port}` |
| `MINIO_ENDPOINT` | MinIO/S3 адрес (включает S3-хранилище) | — |
| `MINIO_ACCESS_KEY` | MinIO access key | — |
| `MINIO_SECRET_KEY` | MinIO secret key | — |
| `MINIO_BUCKET` | Имя бакета | `uphone-uploads` |
| `MINIO_USE_SSL` | SSL для MinIO | `false` |

После запуска:
```bash
# Отредактировать конфиг
sudo nano /etc/uphone/uphone.env
sudo systemctl restart uphone

# Логи
journalctl -u uphone -f
```

| Ресурс | URL |
|--------|-----|
| Веб-клиент | `http://<IP>` |
| API | `http://<IP>/api/v1` |
| WebSocket | `ws://<IP>/ws` |
| Админка | `http://<IP>/admin` |
| Health | `http://<IP>:8080/health` |
| MinIO Console | `http://<IP>:9001` (Docker/прод) |

### Обновление

```bash
cd /opt/uphone
sudo bash deploy/deploy.sh                          # полный деплой
sudo bash deploy/deploy.sh --skip-flutter-build     # без пересборки клиента
sudo bash deploy/deploy.sh --domain=chat.example.com --skip-flutter-build  # с HTTPS
```

Если Flutter web клиент собран локально — скопируйте `client/build/web/` на сервер в `/var/www/uphone/` и запустите с `--skip-flutter-build`.

### Сборка Flutter web локально

На VPS с 1 GB RAM билд Flutter может не хватить памяти. Проще собрать локально:

```bash
cd client
flutter pub get
flutter build web --dart-define=API_BASE_URL=/api/v1 --dart-define=WS_URL=/ws

# Архив для деплоя
cd ..
zip -r deploy/web-build.zip client/build/web/
```

Затем скопировать на сервер:

```bash
# Копируем архив
scp deploy/web-build.zip root@<IP>:/tmp/

# На сервере распаковываем и деплоим
ssh root@<IP>
unzip /tmp/web-build.zip -d /var/www/uphone/
sudo bash /opt/uphone/deploy/deploy.sh --skip-flutter-build
```

Билд: ~46 MB (main.dart.js = 5.5 MB), архив ~17 MB.

### Сборка Android APK

```bash
cd client
flutter pub get

# Debug APK
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://<SERVER_IP>:8080 \
  --dart-define=WS_URL=ws://<SERVER_IP>:8080/ws

# Release APK
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<DOMAIN> \
  --dart-define=WS_URL=wss://<DOMAIN>/ws
```

APK: `client/build/app/outputs/flutter-apk/app-debug.apk`

## Рекомендации по железу

Приватный клуб до ~10 пользователей. Минимальные требования:

| Параметр | Рекомендация |
|----------|-------------|
| **VPS** | 1 vCPU, 1 GB RAM, 20 GB SSD |
| **OS** | Ubuntu 22.04/24.04 LTS |
| **Сеть** | 100 Mbps, статический IP |
| **Домен** | Не обязателен, можно по IP |

Хватит самого дешёвого VPS (Hetzner CX22, Timeweb Cloud 1vCPU/1G, Yandex Cloud standard-v1). Go-сервер и MariaDB весят ~50 MB RAM в простое. MinIO добавляет ~100 MB RAM. Flutter web-клиент — статика ~20-50 MB на диске, раздача Apache2 почти ничего не ест.

**Билд Flutter web** требует ~2-4 GB RAM. Рекомендуется билдить локально и копировать `build/web/` на сервер (`scp -r` или через CI). Если билдить на сервере — ставить swap 2 GB или брать VPS с 2+ GB RAM.

Если нужен видеозвонок (WebRTC) — поднять на VPS с хорошим каналом (1 Gbps).

## Стек

- **Сервер:** Go, chi, gorilla/websocket, Pion WebRTC, Firebase Admin SDK
- **Клиент:** Flutter Web (приоритет), Android
- **БД:** MariaDB 11
- **Файлы:** MinIO/S3 (Docker) или локальная FS (фолбэк)
- **Прокси:** Apache2 (reverse proxy, WebSocket, static files)
- **Админка:** Веб-интерфейс на Go templates, встроенный в бинарник
- **Push:** Firebase Cloud Messaging (Android)
- **Деплой:** Docker Compose (локально) или bare-metal скрипт (прод)

## Структура проекта

```
uphone/
├── client/           # Flutter клиент
│   └── lib/
│       ├── core/     # Конфигурация, сеть, темы, роутер, уведомления
│       ├── features/ # auth, chat, contacts, calls
│       └── shared/   # Модели, общие виджеты
│
├── server/           # Go сервер
│   ├── cmd/server/   # Точка входа (main.go)
│   ├── internal/     # config, auth, chat, contacts, users, webrtc, fcm, admin, middleware, storage
│   └── migrations/   # SQL миграции (001_init..007_call_logs)
│
├── docker/           # Docker Compose (server + MariaDB + MinIO)
│   ├── docker-compose.yml
│   └── Dockerfile.server
│
├── deploy/           # Скрипт развёртывания (bare-metal Ubuntu/Debian)
│   ├── deploy.sh
│   ├── uphone.env.example
│   ├── uphone.service
│   └── uphone.conf
│
└── ARCHITECTURE.md
```

## API

### Авторизация и пользователи

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/v1/auth/register` | Регистрация |
| POST | `/api/v1/auth/login` | Вход |
| POST | `/api/v1/auth/google` | Google OAuth |
| POST | `/api/v1/auth/refresh` | Обновление токена |
| POST | `/api/v1/auth/logout` | Выход |
| POST | `/api/v1/auth/change-password` | Смена пароля |
| GET | `/api/v1/users/me` | Текущий пользователь |
| PUT | `/api/v1/users/me` | Обновить профиль |
| GET | `/api/v1/users/search?q=` | Поиск пользователей |
| GET | `/api/v1/users/:id` | Получить пользователя |
| POST | `/api/v1/users/fcm-token` | Зарегистрировать FCM токен |

### Чаты и сообщения

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/v1/chats` | Создать чат |
| GET | `/api/v1/chats` | Список чатов |
| GET | `/api/v1/chats/:id` | Информация о чате |
| PUT | `/api/v1/chats/:id` | Обновить чат |
| DELETE | `/api/v1/chats/:id` | Удалить чат |
| GET | `/api/v1/chats/:id/members` | Участники |
| POST | `/api/v1/chats/:id/members` | Добавить участника |
| DELETE | `/api/v1/chats/:id/members/:memberId` | Удалить участника |
| POST | `/api/v1/chats/:id/leave` | Покинуть чат |
| POST | `/api/v1/chats/:id/messages` | Отправить сообщение |
| GET | `/api/v1/chats/:id/messages` | История сообщений |
| PUT | `/api/v1/chats/:id/messages/:msgId` | Редактировать |
| DELETE | `/api/v1/chats/:id/messages/:msgId` | Удалить |
| POST | `/api/v1/chats/:id/messages/:msgId/react` | Реакция |
| POST | `/api/v1/chats/:id/messages/:msgId/forward` | Переслать |
| GET | `/api/v1/chats/:id/media` | Медиа-файлы чата |
| POST | `/api/v1/chats/:id/read` | Отметить как прочитанное |
| POST | `/api/v1/upload` | Загрузить файл |

### Контакты

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/v1/contacts` | Список контактов (?q=) |
| POST | `/api/v1/contacts` | Создать контакт |
| GET | `/api/v1/contacts/:id` | Контакт |
| PUT | `/api/v1/contacts/:id` | Обновить контакт |
| DELETE | `/api/v1/contacts/:id` | Удалить контакт |
| GET | `/api/v1/contacts/export?format=vcard\|csv` | Экспорт |
| POST | `/api/v1/contacts/import?format=vcard\|csv` | Импорт |

### Админка

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/v1/admin/users` | Список пользователей |
| POST | `/api/v1/admin/users` | Создать пользователя |
| DELETE | `/api/v1/admin/users/:id` | Удалить пользователя |
| PUT | `/api/v1/admin/users/:id/role` | Сменить роль |
| POST | `/api/v1/admin/users/:id/password` | Сменить пароль |

### WebSocket

| Протокол | Путь | Описание |
|----------|------|----------|
| WS | `/ws?token=` | WebSocket (JSON) |

#### WebSocket — типы сообщений

**Чат:**
- `message.send` → `message.new`
- `typing.start` / `typing.stop`
- `message.read`

**Звонки (WebRTC signal):**
- `call-request` — входящий звонок (1:1)
- `call-invite` — приглашение в групповой звонок
- `call-accept` / `call-reject` / `call-end`
- `call-join` / `call-leave` — групповой звонок
- `participant-joined` / `participant-left`
- `offer` / `answer` / `ice-candidate` — WebRTC SDP/ICE
- `missed_call` — пропущенный звонок (system message + call_log + FCM push)

**Присутствие:**
- `user.online` / `user.offline`

## Возможности клиента

### Звонки
- Аудио и видеозвонки 1:1 (WebRTC P2P)
- Групповые звонки (mesh P2P, до 10 участников)
- Видео-сетка для групповых звонок, PiP для одного удалённого участника
- Локальное превью видео (включая Android)
- Кнопки mute/unmute и toggle камеры
- Скрытый `RTCVideoWeb` для воспроизведения аудио в фоне (web)
- Push-уведомления о входящих звонках (Android, FCM)
- Пропущенные звонки: 30с таймаут → system message + call_log + FCM push

### Чаты
- Личные и групповые чаты, каналы
- Создание групповых чатов с выбором участников (InputChips)
- Настройки чата: аватар, переименование (все типы чатов)
- Управление участниками: добавление/удаление (owner/admin), роль-based UI
- Редактирование и удаление сообщений
- Реакции на сообщения
- Пересылка сообщений
- Индикатор набора текста
- Счётчик непрочитанных, автопрокрутка к первому непрочитанному
- Системные сообщения (пропущенные звонки, приглашения)

### Медиа
- Просмотр изображений (photo_view)
- Встроенный видеоплеер (video_player) с полноэкранным режимом и прогресс-баром
- Встроенный аудиоплеер
- Загрузка файлов (изображения, видео, документы)
- Экспорт/импорт контактов (vCard, CSV)

### Другое
- Google OAuth
- Админ-панель (web)
- Push-уведомления (Firebase Cloud Messaging)
- Автоподключение WebSocket с реконнектом
- Тёмная/светлая тема
- Хранение файлов: MinIO/S3 (Docker) или локальная FS

## Админ-панель

Веб-интерфейс для управления пользователями, встроенный в Go-сервер.

```
http://localhost:8080/admin
```

По умолчанию: `blkdem@blkdem.ru` / `12345678`

Функции: список пользователей, создание, удаление, смена ролей (admin/user), смена паролей.

Авторизация через JWT cookie (`admin_token`). Сессия действует 15 минут (как access token).
