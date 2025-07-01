# Інструкція з встановлення Matrix Dendrite Setup

## 1. Клонування репозиторію
```bash
git clone https://github.com/Karnemorkon/matrix-dendrite-setup.git
cd matrix-dendrite-setup
```

## 2. Підготовка та запуск інсталятора
```bash
# Копіювання конфігурації
cp env.example .env

# Запуск інтерактивного інсталятора
chmod +x scripts/install.sh
./scripts/install.sh
```

## 3. Налаштування .env
- Вкажіть домен, паролі, токени та інші параметри у файлі `.env` (створюється автоматично з прикладу).
- Або відредагуйте файл вручну: `nano .env`

## 4. Запуск сервісів
```bash
docker-compose up -d
```

## 5. Доступ до сервісів
- Matrix сервер: http://<ваш_домен>:8008
- Веб-клієнт: http://<ваш_домен>
- Адмін-панель: http://<ваш_домен>/admin
- Grafana: http://<ваш_домен>:3000

## 6. Резервне копіювання
- Автоматичне резервне копіювання виконується контейнером `backup`.
- Для ручного запуску: `docker-compose run --rm backup`
- Для відновлення: `docker-compose run --rm backup /scripts/restore.sh <шлях_до_бекапу>`

## 7. Додатково
- Для налаштування мостів, Cloudflare Tunnel, Matrix-бота — редагуйте `.env` та відповідні конфіги у `config/`.

---

# Питання? Дивіться [FAQ](FAQ.md) або створіть issue на GitHub. 