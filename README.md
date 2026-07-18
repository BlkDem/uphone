# UPhone

Мультиплатформенный мессенджер корпоративного уровня.

## Быстрый старт

### Требования

- Docker + Docker Compose
- Go 1.23+ (для локальной разработки)

### Запуск инфраструктуры

```bash
cd docker
docker-compose up -d
```

Сервер: http://localhost:8080/health

### Локальная разработка

```bash
cd server
go mod tidy
go run ./cmd/server
```

### Тесты

```bash
cd server
go test ./...
```

## Стек

- **Сервер:** Go, chi, gorilla/websocket, Pion WebRTC
- **Клиент:** Flutter (Web, Windows, Linux, Android)
- **БД:** MariaDB 11
- **Файлы:** Локальная FS

## Структура

```
uphone/
├── client/       # Flutter клиент
├── server/       # Go сервер
├── docker/       # Docker Compose
├── docs/         # Документация
└── uploads/      # Файлы (git ignored)
```
