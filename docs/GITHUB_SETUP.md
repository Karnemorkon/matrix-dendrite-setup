# Налаштування GitHub для автоматичної збірки Docker образів

Цей документ описує, як налаштувати GitHub для автоматичної збірки та публікації Docker образів.

## 🔐 Налаштування GitHub Secrets

### 1. Перейдіть до налаштувань репозиторію

1. Відкрийте ваш GitHub репозиторій
2. Перейдіть до **Settings** → **Secrets and variables** → **Actions**
3. Натисніть **New repository secret**

### 2. Додайте необхідні секрети

#### DOCKER_USERNAME
- **Name**: `DOCKER_USERNAME`
- **Value**: ваш Docker Hub username (наприклад: `morkon06`)
- **Description**: Docker Hub username для публікації образів

#### DOCKER_PASSWORD
- **Name**: `DOCKER_PASSWORD`
- **Value**: ваш Docker Hub password або access token
- **Description**: Docker Hub password/token для авторизації

### 3. Як створити Docker Hub Access Token

1. Увійдіть на [Docker Hub](https://hub.docker.com)
2. Перейдіть до **Account Settings** → **Security**
3. Натисніть **New Access Token**
4. Введіть назву токена (наприклад: "GitHub Actions")
5. Виберіть **Read & Write** права
6. Скопіюйте токен та збережіть його як `DOCKER_PASSWORD`

## 🚀 Автоматична збірка

### При створенні тегу

```bash
# Створення тегу для автоматичної збірки
git tag v1.0.1
git push origin v1.0.1
```

### Ручний запуск

1. Перейдіть до **Actions** в GitHub
2. Виберіть workflow **Build and Push Docker Images**
3. Натисніть **Run workflow**
4. Введіть версію (наприклад: `v1.0.1`)
5. Натисніть **Run workflow**

## 📋 Перевірка налаштувань

### 1. Перевірте секрети

```bash
# Перевірте, чи секрети встановлені
# (це можна зробити тільки через GitHub UI)
```

### 2. Тестовий запуск

```bash
# Створіть тестовий тег
git tag v1.0.0-test
git push origin v1.0.0-test
```

### 3. Перевірте результати

1. Перейдіть до **Actions** в GitHub
2. Знайдіть завершений workflow
3. Перевірте, чи образи опубліковані на Docker Hub

## 🔧 Troubleshooting

### Помилка авторизації

```
denied: requested access to the resource is denied
```

**Рішення:**
- Перевірте правильність `DOCKER_USERNAME` та `DOCKER_PASSWORD`
- Переконайтеся, що токен має права на запис

### Помилка збірки

```
Error: buildx failed with: error: failed to solve
```

**Рішення:**
- Перевірте Dockerfile'и на синтаксичні помилки
- Переконайтеся, що всі залежності доступні

### Помилка публікації

```
Error: failed to push some refs
```

**Рішення:**
- Перевірте права доступу до Docker Hub
- Переконайтеся, що репозиторій існує на Docker Hub

## 📝 Приклади використання

### Створення нового релізу

```bash
# 1. Оновіть код
git add .
git commit -m "Add new features"
git push origin main

# 2. Створіть тег
git tag v1.1.0
git push origin v1.1.0

# 3. GitHub Actions автоматично зіб'є та опублікує образи
```

### Використання готових образів

```yaml
# docker-compose.yml
version: '3.9'

services:
  admin-panel:
    image: morkon06/matrix-dendrite-setup-admin-panel:latest
    # або конкретна версія:
    # image: morkon06/matrix-dendrite-setup-admin-panel:v1.0.0
    
  matrix-bot:
    image: morkon06/matrix-dendrite-setup-matrix-bot:latest
    # або конкретна версія:
    # image: morkon06/matrix-dendrite-setup-matrix-bot:v1.0.0
```

## 🔒 Безпека

- Ніколи не комітьте секрети в код
- Використовуйте access tokens замість паролів
- Регулярно оновлюйте токени
- Обмежуйте права токенів до мінімуму

## 📞 Підтримка

Якщо виникли проблеми:

1. Перевірте логи в GitHub Actions
2. Перевірте налаштування секретів
3. Перевірте права доступу до Docker Hub
4. Створіть issue в репозиторії з деталями помилки 