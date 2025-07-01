# API Документація - Matrix Dendrite Admin Panel

## Загальна інформація

Базовий URL: `http://your-domain:8080/api`

Всі запити потребують авторизації через JWT токен у заголовку:
```
Authorization: Bearer <token>
```

## Автентифікація

### POST /api/auth/login
Вхід в систему.

**Тіло запиту:**
```json
{
  "username": "admin",
  "password": "password"
}
```

**Відповідь:**
```json
{
  "success": true,
  "token": "jwt_token_here",
  "username": "admin"
}
```

### POST /api/auth/register
Реєстрація нового користувача.

**Тіло запиту:**
```json
{
  "username": "newuser",
  "password": "password"
}
```

## Сервіси

### GET /api/status
Отримання статусу всіх сервісів.

### POST /api/service/{action}/{name}
Керування сервісом (start/stop/restart).

**Приклади:**
- `POST /api/service/start/dendrite`
- `POST /api/service/stop/postgres`
- `POST /api/service/restart/redis`

## Користувачі Matrix

### GET /api/matrix/users
Список користувачів Matrix.

### POST /api/matrix/users
Створення користувача Matrix.

**Тіло запиту:**
```json
{
  "username": "newuser",
  "password": "password",
  "displayName": "New User"
}
```

### DELETE /api/matrix/users/{username}
Видалення користувача Matrix.

### POST /api/matrix/users/{username}/password
Зміна пароля користувача.

**Тіло запиту:**
```json
{
  "password": "newpassword"
}
```

## Бекапи

### GET /api/backups
Список бекапів.

### POST /api/backups
Створення нового бекапу.

### POST /api/backups/{name}/restore
Відновлення бекапу.

### DELETE /api/backups/{name}
Видалення бекапу.

## Мости

### GET /api/bridges/status
Статус всіх мостів (Signal, WhatsApp, Discord).

### POST /api/bridges/restart/{name}
Перезапуск моста.

## Моніторинг

### GET /api/health
Детальна перевірка здоров'я всіх сервісів.

**Відповідь:**
```json
{
  "success": true,
  "health": [
    {
      "name": "dendrite",
      "status": "running",
      "healthy": true
    }
  ],
  "summary": {
    "total": 10,
    "healthy": 9,
    "unhealthy": 1
  }
}
```

### GET /api/metrics
Метрики системи (CPU, пам'ять, мережа).

## Аудит

### GET /api/audit
Отримання журналу аудиту (історія дій).

**Відповідь:**
```json
{
  "success": true,
  "logs": [
    {
      "timestamp": "2024-01-01T12:00:00Z",
      "user": "admin",
      "action": "service_start",
      "details": {"service": "dendrite"},
      "result": "success"
    }
  ]
}
```

## Оновлення

### POST /api/update
Автоматичне оновлення всіх контейнерів.

**Процес:**
1. Створення бекапу
2. Оновлення Docker образів (`docker-compose pull`)
3. Перезапуск контейнерів (`docker-compose up -d`)
4. Перевірка стану після оновлення

## Сповіщення

### POST /api/notifications/send
Надсилання сповіщення через Matrix.

**Тіло запиту:**
```json
{
  "message": "Текст сповіщення",
  "roomId": "!roomid:domain.com"
}
```

## Інтеграція з Matrix ботом

Бот використовує ці API endpoints для:
- Отримання статусу сервісів (`/api/health`)
- Керування сервісами (`/api/service/*`)
- Створення/видалення користувачів (`/api/matrix/users/*`)
- Керування бекапами (`/api/backups/*`)
- Оновлення контейнерів (`/api/update`)
- Надсилання сповіщень (`/api/notifications/send`)

### Команди бота:
- `/status` - статус сервісів
- `/health` - детальний healthcheck
- `/update` - оновлення контейнерів
- `/user create/delete/list` - керування користувачами
- `/backup create/list/restore` - керування бекапами
- `/bridges status/restart` - керування мостами

## Помилки

Всі endpoints повертають помилки у форматі:
```json
{
  "success": false,
  "error": "Опис помилки"
}
```

Код статусу HTTP:
- `200` - успіх
- `400` - невірний запит
- `401` - неавторизований
- `404` - не знайдено
- `500` - внутрішня помилка сервера 