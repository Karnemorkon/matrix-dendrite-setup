# Matrix Dendrite Setup 🚀

Повноцінна система для розгортання Matrix Dendrite сервера з мостами, веб дашбордом та автоматичним резервним копіюванням.

## 🌟 Особливості

- **Matrix Dendrite** - легковісний Matrix сервер
- **Мости** - Signal, WhatsApp, Discord
- **Веб дашборд** - адміністративний панель з метриками
- **Автоматичні бекапи** - з управлінням через веб інтерфейс
- **Система сповіщень** - Matrix бот для моніторингу
- **Docker Compose** - просте розгортання
- **SSL/TLS** - підтримка Cloudflare Tunnel

## 📋 Вимоги

- Linux (Ubuntu 20.04+ / Debian 11+)
- Docker та Docker Compose
- Мінімум 2GB RAM
- 10GB вільного місця
- Домен (для Cloudflare Tunnel)

## 🚀 Швидкий старт

### Вимоги
- Docker та Docker Compose
- Git
- Bash

### Встановлення

```bash
# Клонування репозиторію
git clone https://github.com/your-username/matrix-dendrite-setup.git
cd matrix-dendrite-setup

# Копіювання конфігурації
cp env.example .env

# Редагування налаштувань
nano .env

# Запуск встановлення
bash scripts/install.sh
```

### Використання готових Docker образів

Для швидшого розгортання можна використовувати готові Docker образи:

```bash
# Використання в docker-compose.yml
# Замість build: ./dashboard/admin-panel
image: morkon06/matrix-dendrite-setup-admin-panel:latest

# Замість build: ./config/bot  
image: morkon06/matrix-dendrite-setup-matrix-bot:latest
```

### Налаштування GitHub для автоматичної збірки

1. **Додайте секрети в GitHub:**
   - `DOCKER_USERNAME` - ваш Docker Hub username
   - `DOCKER_PASSWORD` - ваш Docker Hub access token

2. **Створіть тег для автоматичної збірки:**
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

3. **Перевірте результати в GitHub Actions**

Детальні інструкції: [docs/GITHUB_SETUP.md](docs/GITHUB_SETUP.md)

Детальніше в [Docker Images Guide](docs/DOCKER_IMAGES.md).

## 📁 Структура проекту

```
matrix-dendrite-setup/
├── docker-compose.yml          # Основний compose файл
├── .env.example               # Приклад змінних середовища
├── scripts/
│   ├── install.sh             # Інтерактивний інсталятор
│   ├── backup.sh              # Скрипт бекапу
│   └── restore.sh             # Скрипт відновлення
├── config/                    # Конфігураційні файли
├── dashboard/                 # Веб дашборд та адмін панель
├── docs/                      # Документація
└── backup/                    # Сховище бекапів
```

## 🔧 Компоненти

### Core Services
- **Dendrite** - Matrix сервер
- **PostgreSQL** - база даних
- **Redis** - кеш

### Bridges
- **mautrix-signal** - Signal міст
- **mautrix-whatsapp** - WhatsApp міст  
- **mautrix-discord** - Discord міст

### Monitoring & Management
- **Grafana** - метрики та дашборди
- **Prometheus** - збір метрик
- **Admin Panel** - веб інтерфейс керування
- **Matrix Bot** - сповіщення та моніторинг

### Web Interface
- **Element Web** - веб клієнт
- **Nginx** - reverse proxy

## 📊 Моніторинг

- Веб дашборд доступний за адресою: `http://your-domain/admin`
- Grafana метрики: `http://your-domain/grafana`
- Element Web клієнт: `http://your-domain`

## 🔒 Безпека

- Автоматичні SSL сертифікати через Cloudflare
- Ізольовані Docker контейнери
- Регулярні бекапи з шифруванням
- Моніторинг безпеки

## 📚 Документація

- [Інструкція встановлення](docs/INSTALL.md)
- [Налагодження](docs/TROUBLESHOOTING.md)
- [API документація](docs/API.md)

## 🤝 Підтримка

Якщо у вас виникли питання або проблеми:
1. Перевірте [FAQ](docs/FAQ.md)
2. Створіть [Issue](https://github.com/Karnemorkon/matrix-dendrite-setup/issues)
3. Зверніться до [документації](docs/)

## 📄 Ліцензія

MIT License - дивіться [LICENSE](LICENSE) файл для деталей.

## Matrix-бот для керування сервером

Matrix-бот дозволяє керувати сервером, мостами, бекапами, користувачами та отримувати статуси через команди у Matrix-кімнаті.

### Можливості:
- Перегляд статусу сервісів: `/status`
- Перегляд логів: `/logs <service> [lines]`
- Запуск/зупинка/перезапуск сервісу: `/start <service>`, `/stop <service>`, `/restart <service>`
- Керування бекапами: `/backup create`, `/backup list`, `/backup restore <name>`
- Керування користувачами: `/user create <username> <password>`, `/user list`, `/user delete <username>`
- Статус мостів: `/bridges status`, `/bridges restart <name>`
- Healthcheck: `/health`
- Довідка: `/help`

### Приклад використання:
```
/status
/restart dendrite
/logs postgres 50
/backup create
/user create john password123
```

### Налаштування змінних оточення для бота
Додайте у `.env`:
```
MATRIX_BOT_USERNAME=system-bot
MATRIX_BOT_PASSWORD=your-bot-password
MATRIX_BOT_ROOM_ID=!yourroomid:yourdomain
```

### Безпека
- Бот реагує лише у вказаній кімнаті (MATRIX_BOT_ROOM_ID)
- Можна додати whitelist користувачів у bot.py
- Всі дії логуються у audit log

### Запуск
Бот автоматично запускається через docker-compose. Для ручного запуску:
```
cd config/bot
python3 bot.py
```

---
Детальніше див. у розділі "Адмін-панель та бот".

⭐ Якщо проект вам сподобався, поставте зірку! 