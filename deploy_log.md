# UPhone Deployment Log

## Server: 82.202.139.112 (user1)
## Domain: up.umolab.ru (Cloudflare + FastPanel)

---

## 1. Windows Desktop (client) - завершено

### WinToast / proper notifications
- `windows_tray_service.dart` — `WinToast::initialize()` с AUMID `com.uphone.messenger` и CLSID `2EB1AE51-98B7-4C2B-B1A0-000000000001`
- `showNotification()` — создаёт `ToastChildVisual` с title + body, вызывает `WinToast.instance().showToast(toast)`
- `TitleBarStyle.hidden` исправлен на `normal` — окно можно свернуть
- `setPreventClose(true)` — закрытие сворачивает в трей, а не завершает процесс
- Иконка трея — `assets/tray_icon.ico` (сгенерирована из `logo.png` через Pillow: 16/32/48/64/128/256)
- Иконка окна — `windows/runner/resources/app_icon.ico` (та же)
- Заголовок: `window.Create(L"UPhone Messenger", ...)` в `main.cpp`
- Размер окна: `1100×720` (было 420×720)

### Уведомления из WebSocket
- `ChatNotifier._handleWsMessage()` → для `message.new` от другого пользователя вызывает `NotificationService.showNewMessageNotification(senderName, preview)`
- На Windows вызывает `WindowsTrayService.showNotification`

### Web-подобный sidebar на Windows
- `WebShellScreen._useSidebarLayout` → `kIsWeb || Platform.isWindows`
- `ChatListScreen` → плейсхолдер "Select a chat" на Windows тоже

### Ветки слиты в master
- `feat/windows-toasts` (92c1498)
- `fix/window-title` (0633003)
- `feat/windows-web-layout` (e1d7c51)

---

## 2. Production Deployment

### Server environment
- Ubuntu 24.04, x86_64, 4GB RAM
- MySQL 8.0 на localhost:3306, БД `up_umolab_ru`, юзер `up_umolab_ru`
- FastPanel (FastPanel2) — управляет nginx + Apache + Let's Encrypt
- Docker отсутствует — Go бинарник собран под linux/amd64

### Архитектура nginx
- **system nginx** (`/usr/sbin/nginx`) — слушает `82.202.139.112:80` и `82.202.139.112:443`
  - Конфиги: `/etc/nginx/conf.d/*.conf`, `/etc/nginx/fastpanel2-sites/*/*.conf`
  - SSL: `/var/www/httpd-cert/up.umolab.ru_2026-07-28-19-30_09.crt` (Let's Encrypt)
- **fastpanel2-nginx** (`/usr/local/sbin/fastpanel2-nginx`) — слушает `:8888` (админка) и `:7777` (fastlinks)
- **Apache** — на `127.0.0.1:81`

### База данных — миграции
- MySQL 8.0 не поддерживает `IF NOT EXISTS` для `CREATE INDEX` и `ALTER TABLE ... ADD COLUMN`
- Удалены `IF NOT EXISTS` из 7 индексов и 3 колонок в `server/migrations/*.sql`
- `migrate.go` — `isIgnorableError()` игнорирует ошибки MySQL 1050 (таблица существует), 1061 (дубликат ключа), 1060 (дубликат колонки)

### MinIO
- Установлен с `dl.min.io`, systemd unit `uphone-minio.service`
- Bucket `uphone-uploads`, public, credentials `uphone_minio` / `uphone_minio_secret_2026`
- API на `:9000`, Console на `:9001`

### Go server
- Сборка: `GOOS=linux GOARCH=amd64 go build -o uphone-server-linux ./cmd/server/`
- Бинарник: `/opt/uphone/uphone-server`
- Конфиг: `/opt/uphone/.env` (DB, MinIO, JWT_SECRET, FCM service-account)
- FCM: `uphone-messenger-firebase-adminsdk-fbsvc-6766358e52.json` → `/opt/uphone/service-account.json`
- Systemd: `/etc/systemd/system/uphone-server.service`
- Старт: `FCM initialized`, `S3 connected`, сервер на `:8080`

### nginx proxy (FastPanel managed config)
- `/etc/nginx/fastpanel2-available/fastuser/up.umolab.ru.conf` — основной конфиг
- `/etc/nginx/fastpanel2-sites/fastuser/up.umolab.ru.includes` — кастомные location'ы
- `client_max_body_size 100m;`
- **Proxy routes:**
  - `/ws` → WebSocket → `127.0.0.1:8080/ws`
  - `/api/` → `127.0.0.1:8080`
  - `/admin/` → `127.0.0.1:8080`
  - `/uploads/` → `/opt/uphone/uploads/`
- SPA: `try_files $uri $uri/ /index.html;`

### Flutter Web client
- Сборка: `flutter build web --release --dart-define=API_BASE_URL=https://up.umolab.ru --dart-define=WS_URL=wss://up.umolab.ru/ws`
- 42 файла, ~46 MB (включая canvaskit)
- Webroot: `/var/www/fastuser/data/www/up.umolab.ru/`
- Владелец: `fastuser:fastuser`
- `index.html` → `<title>UPhone</title>`
- Доступен по `https://up.umolab.ru` (Cloudflare + Let's Encrypt)

---

## 3. Что ещё нужно / следующие шаги

1. **Проверить регистрацию/логин** через Flutter web на `https://up.umolab.ru` — из браузера
2. **WebSocket** — проверить, что чат работает через WSS
3. **Cloudflare SSL/TLS** — убедиться, что режим Full (Strict) или Full. Если Flexible — nginx отдаёт HTTP, Cloudflare терминирует SSL.
4. **FastPanel regenerates config** — если поменять настройки домена в админке FastPanel, конфиг перезапишется (пропадут кастомные правки). Нужно либо внести изменения в интерфейсе FastPanel, либо повторно применить патчи.
5. **Загрузка файлов** — проверить, что `client_max_body_size 100m` работает через прокси
6. **Мониторинг** — `journalctl -u uphone-server -f` для логов в реальном времени

---

## Credentials (production)

| Service | Host | Port | User | Password/Key |
|---------|------|------|------|-------------|
| MySQL | localhost | 3306 | up_umolab_ru | Ytex3_Jrub4Cc1(l |
| MinIO API | localhost | 9000 | uphone_minio | uphone_minio_secret_2026 |
| MinIO Console | localhost | 9001 | uphone_minio | uphone_minio_secret_2026 |
| SSH | 82.202.139.112 | 22 | user1 | (SSH key) |
| FCM | — | — | — | service-account.json |
| JWT | — | — | — | M8XpK2vR5nL9qW3y7J4fC6hA1sD0gEbN |
| Domain | up.umolab.ru | — | — | FastPanel (Let's Encrypt) |
