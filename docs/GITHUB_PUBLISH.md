# Публікація проекту на GitHub

Цей документ описує, як опублікувати проект на GitHub та налаштувати автоматичну збірку Docker образів.

## 📋 Підготовка до публікації

### 1. Створення репозиторію на GitHub

1. Перейдіть на [GitHub](https://github.com)
2. Натисніть **New repository**
3. Введіть назву: `matrix-dendrite-setup`
4. Виберіть **Public** або **Private**
5. **НЕ** створюйте README, .gitignore або license (вони вже є)
6. Натисніть **Create repository**

### 2. Підключення локального репозиторію

```bash
# Додайте remote origin
git remote add origin https://github.com/YOUR_USERNAME/matrix-dendrite-setup.git

# Перевірте remote
git remote -v

# Відправте код на GitHub
git push -u origin main

# Відправте теги
git push origin --tags
```

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
- **Value**: ваш Docker Hub access token
- **Description**: Docker Hub access token для авторизації

### 3. Як створити Docker Hub Access Token

1. Увійдіть на [Docker Hub](https://hub.docker.com)
2. Перейдіть до **Account Settings** → **Security**
3. Натисніть **New Access Token**
4. Введіть назву токена (наприклад: "GitHub Actions")
5. Виберіть **Read & Write** права
6. Скопіюйте токен та збережіть його як `DOCKER_PASSWORD`

## 🚀 Тестування автоматичної збірки

### 1. Створення тестового тегу

```bash
# Створіть тестовий тег
git tag v1.0.0-test
git push origin v1.0.0-test
```

### 2. Перевірка GitHub Actions

1. Перейдіть до **Actions** в GitHub
2. Знайдіть workflow **Build and Push Docker Images**
3. Перевірте, чи workflow запустився
4. Дочекайтеся завершення збірки

### 3. Перевірка результатів

1. Перейдіть на [Docker Hub](https://hub.docker.com)
2. Знайдіть ваші образи:
   - `your-username/matrix-dendrite-setup-admin-panel`
   - `your-username/matrix-dendrite-setup-matrix-bot`

## 📝 Створення релізу

### 1. Підготовка коду

```bash
# Оновіть код
git add .
git commit -m "Add new features"
git push origin main
```

### 2. Створення тегу

```bash
# Створіть тег
git tag v1.1.0
git push origin v1.1.0
```

### 3. GitHub автоматично:

- Зіб'є Docker образи
- Опублікує їх на Docker Hub
- Створить GitHub Release
- Оновить теги `latest`

## 🔧 Troubleshooting

### Помилка авторизації

```
denied: requested access to the resource is denied
```

**Рішення:**
- Перевірте правильність `DOCKER_USERNAME` та `DOCKER_PASSWORD`
- Переконайтеся, що токен має права на запис

### Workflow не запускається

**Рішення:**
- Перевірте, чи створений тег правильно
- Переконайтеся, що файл `.github/workflows/build-images.yml` існує
- Перевірте логи в GitHub Actions

### Помилка збірки

```
Error: buildx failed with: error: failed to solve
```

**Рішення:**
- Перевірте Dockerfile'и на синтаксичні помилки
- Переконайтеся, що всі залежності доступні

## 📊 Моніторинг

### GitHub Actions

- Перейдіть до **Actions** в GitHub
- Переглядайте логи збірки
- Налаштуйте сповіщення про помилки

### Docker Hub

- Перевіряйте статистику завантажень
- Моніторте розмір образів
- Переглядайте версії

## 🔒 Безпека

### Рекомендації

- Використовуйте access tokens замість паролів
- Регулярно оновлюйте токени
- Обмежуйте права токенів до мінімуму
- Не комітьте секрети в код

### Перевірка безпеки

```bash
# Перевірте, чи немає секретів в коді
grep -r "password\|token\|secret" . --exclude-dir=node_modules --exclude-dir=.git
```

## 📞 Підтримка

Якщо виникли проблеми:

1. Перевірте логи в GitHub Actions
2. Перевірте налаштування секретів
3. Перевірте права доступу до Docker Hub
4. Створіть issue в репозиторії з деталями помилки

## 🎯 Наступні кроки

1. **Налаштуйте сповіщення** про нові релізи
2. **Додайте опис** до Docker Hub образів
3. **Створіть документацію** для користувачів
4. **Налаштуйте CI/CD** для тестування
5. **Додайте badges** в README.md 