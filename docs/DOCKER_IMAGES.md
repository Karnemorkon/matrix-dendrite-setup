# Docker Images - Matrix Dendrite Setup

Цей документ описує, як збирати та використовувати Docker образи для Matrix Dendrite Setup.

## Доступні образи

Проект містить два власних Docker образи:

1. **Admin Panel** - веб-інтерфейс для керування сервером
2. **Matrix Bot** - бот для керування через Matrix команди

## Збірка образів

### Локальна збірка

```bash
# Збірка всіх образів
bash scripts/build-images.sh

# Збірка з кастомними параметрами
bash scripts/build-images.sh --username myuser --repo my-matrix --version v1.0.0

# Збірка та публікація на Docker Hub
bash scripts/build-images.sh --username myuser --push
```

### Параметри скрипта

- `--username` - Docker Hub username (за замовчуванням: your-dockerhub-username)
- `--repo` - Repository name (за замовчуванням: matrix-dendrite-setup)
- `--version` - Version tag (за замовчуванням: latest)
- `--push` - Публікувати образи на Docker Hub
- `--help` - Показати довідку

### Ручна збірка

```bash
# Admin Panel
docker build -t myuser/matrix-dendrite-setup-admin-panel:latest ./dashboard/admin-panel

# Matrix Bot
docker build -t myuser/matrix-dendrite-setup-matrix-bot:latest ./config/bot
```

## Публікація на Docker Hub

### 1. Створення облікового запису

1. Зареєструйтесь на [Docker Hub](https://hub.docker.com)
2. Створіть репозиторій для ваших образів

### 2. Авторизація

```bash
docker login
```

### 3. Публікація

```bash
# Публікація всіх образів
bash scripts/build-images.sh --username your-username --push

# Публікація конкретного образу
docker push your-username/matrix-dendrite-setup-admin-panel:latest
docker push your-username/matrix-dendrite-setup-matrix-bot:latest
```

## Автоматична збірка через GitHub Actions

### Налаштування

1. Додайте секрети в GitHub repository:
   - `DOCKER_USERNAME` - ваш Docker Hub username
   - `DOCKER_PASSWORD` - ваш Docker Hub password/token

2. Workflow автоматично запускається при:
   - Пуші тегів (v*)
   - Ручному запуску через GitHub Actions

### Використання

```bash
# Створення тегу для автоматичної збірки
git tag v1.0.0
git push origin v1.0.0
```

## Використання готових образів

### В docker-compose.yml

```yaml
# Замість локальної збірки
# build: ./dashboard/admin-panel

# Використовуйте готовий образ
image: your-username/matrix-dendrite-setup-admin-panel:latest

# Замість локальної збірки
# build: ./config/bot

# Використовуйте готовий образ
image: your-username/matrix-dendrite-setup-matrix-bot:latest
```

### Повний приклад

```yaml
version: '3.9'

services:
  admin-panel:
    image: your-username/matrix-dendrite-setup-admin-panel:latest
    container_name: admin-panel
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./scripts:/scripts:ro
      - ./backup:/backup
    ports:
      - "8080:3000"
    environment:
      - NODE_ENV=production
    networks:
      - matrix

  matrix-bot:
    image: your-username/matrix-dendrite-setup-matrix-bot:latest
    container_name: matrix-bot
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - MATRIX_HOMESERVER_URL=http://dendrite:8008
      - MATRIX_BOT_USERNAME=${MATRIX_BOT_USERNAME}
      - MATRIX_BOT_PASSWORD=${MATRIX_BOT_PASSWORD}
      - MATRIX_BOT_ROOM_ID=${MATRIX_BOT_ROOM_ID}
      - ADMIN_PANEL_URL=http://admin-panel:3000
    depends_on:
      - dendrite
      - admin-panel
    networks:
      - matrix

networks:
  matrix:
    driver: bridge
```

## Переваги використання готових образів

1. **Швидкість розгортання** - не потрібно збирати образи
2. **Надійність** - образи протестовані та стабільні
3. **Зручність** - простіше розгортання для користувачів
4. **Версіонування** - можна використовувати конкретні версії

## Структура образів

### Admin Panel Image

- **Base**: node:18-alpine
- **Port**: 3000
- **User**: nodejs (1001)
- **Features**: Express.js, Docker API, JWT auth

### Matrix Bot Image

- **Base**: python:3.11-slim
- **User**: bot (1001)
- **Features**: matrix-nio, requests, async/await

## Безпека

- Всі образи використовують непривілейованих користувачів
- Мінімальні базові образи (alpine/slim)
- Безпечні практики збірки
- Регулярні оновлення базових образів

## Підтримка

- Образи підтримують архітектури: amd64, arm64
- Тестовані на Ubuntu, Debian, CentOS
- Підтримка Docker Compose v2+ 