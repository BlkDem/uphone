# UPhone

Мультиплатформенный мессенджер: чаты, контакты, аудио/видео звонки (WebRTC), об файлами.

## Быстрый старт

### Требования

- Go 1.24+
- Flutter 3.x (stable)
- MariaDB 11+
- Apache2 (для прода) или直接 Go сервер (для разработки)

### Локальная разработка

```bash
# Сервер
cd server
go mod tidy
# Запуск (предварительно создать БД и применить миграции)
DB_HOST=127.0.0.1 DB_PORT=3307 DB_USER=uphone DB_PASSWORD=uphone_secret \
  SERVER_PORT=8080 GOOGLE_CLIENT_ID=<your_id> go run ./cmd/server

# Клиент
cd client
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=WS_URL=ws://localhost:8080/ws
```

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
sudo bash deploy/deploy.sh
```

Скрипт автоматически:
- Устанавливает Go, Flutter, MariaDB, Apache2
- Создаёт базу данных и пользователя
- Собирает Go сервер и Flutter web-клиент
- Настраивает systemd сервис и Apache2 (reverse proxy + WebSocket)
- Генерирует JWT секрет

После запуска:
```bash
# Отредактировать конфиг (Google Client ID и т.д.)
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

Конфиг: `/etc/uphone/uphone.env`

### Обновление

```bash
cd /opt/uphone
sudo bash deploy/deploy.sh
```

## Стек

- **Сервер:** Go, chi, gorilla/websocket, Pion WebRTC
- **Клиент:** Flutter Web (приоритет), Android
- **БД:** MariaDB 11
- **Файлы:** Локальная FS (`/var/lib/uphone/uploads`)
- **Прокси:** Apache2 (reverse proxy, WebSocket, static files)
- **Админка:** Веб-интерфейс на Go templates, встроенный в бинарник

## Структура проекта

```
uphone/
├── client/           # Flutter клиент
│   └── lib/
│       ├── core/     # Конфигурация, сеть, темы, роутер
│       ├── features/ # auth, chat, contacts, calls
│       └── shared/   # Модели, общие виджеты
│
├── server/           # Go сервер
│   ├── cmd/server/   # Точка входа (main.go)
│   ├── internal/     # config, auth, chat, contacts, users, webrtc, admin, middleware
│   └── migrations/   # SQL миграции (001_init..004_admin)
│
├── deploy/           # Скрипт развёртывания
│   ├── deploy.sh     # Основной скрипт
│   ├── uphone.env.example
│   ├── uphone.service
│   └── uphone.conf
│
└── ARCHITECTURE.md
```

## API

| Метод | Путь | Описание |
|-------|------|----------|
| POST | `/api/v1/auth/register` | Регистрация |
| POST | `/api/v1/auth/login` | Вход |
| POST | `/api/v1/auth/google` | Google OAuth |
| POST | `/api/v1/auth/refresh` | Обновление токена |
| POST | `/api/v1/auth/logout` | Выход |
| GET | `/api/v1/users/me` | Текущий пользователь |
| PUT | `/api/v1/users/me` | Обновить профиль |
| GET | `/api/v1/users/search?q=` | Поиск пользователей |
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
| POST | `/api/v1/upload` | Загрузить файл |
| GET | `/api/v1/contacts` | Список контактов (?q=) |
| POST | `/api/v1/contacts` | Создать контакт |
| GET | `/api/v1/contacts/:id` | Контакт |
| PUT | `/api/v1/contacts/:id` | Обновить контакт |
| DELETE | `/api/v1/contacts/:id` | Удалить контакт |
| GET | `/api/v1/contacts/export?format=vcard\|csv` | Экспорт |
| POST | `/api/v1/contacts/import?format=vcard\|csv` | Импорт |
| GET | `/api/v1/admin/users` | Список пользователей (admin) |
| POST | `/api/v1/admin/users` | Создать пользователя (admin) |
| DELETE | `/api/v1/admin/users/:id` | Удалить пользователя (admin) |
| PUT | `/api/v1/admin/users/:id/role` | Сменить роль (admin) |
| POST | `/api/v1/admin/users/:id/password` | Сменить пароль (admin) |
| WS | `/ws?token=` | WebSocket |

## Админ-панель

Веб-интерфейс для управления пользователями, встроенный в Go-сервер.

```
http://localhost:8080/admin
```

По умолчанию: `blkdem@blkdem.ru` / `12345678`

Функции: список пользователей, создание, удаление, смена ролей (admin/user), смена паролей.

Авторизация через JWT cookie (`admin_token`). Сессия действует 15 минут (как access token).
