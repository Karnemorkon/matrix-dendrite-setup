#!/bin/bash

# Matrix Dendrite Setup - Інтерактивний інсталятор
# Автор: Matrix Setup Team
# Версія: 1.0.0

set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функції логування
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Перевірка системних вимог
check_system_requirements() {
    log "Перевірка системних вимог..."
    
    # Перевірка ОС
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "Цей скрипт підтримується тільки на Linux"
        exit 1
    fi
    
    # Перевірка прав root
    if [[ $EUID -eq 0 ]]; then
        warn "Скрипт запущений з правами root"
    fi
    
    # Перевірка доступної пам'яті
    local mem_total=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
    if [[ $mem_total -lt 2 ]]; then
        error "Потрібно мінімум 2GB RAM. Доступно: ${mem_total}GB"
        exit 1
    fi
    
    # Перевірка вільного місця
    local disk_free=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $disk_free -lt 10 ]]; then
        error "Потрібно мінімум 10GB вільного місця. Доступно: ${disk_free}GB"
        exit 1
    fi
    
    log "Системні вимоги виконані ✓"
}

# Встановлення Docker
install_docker() {
    log "Перевірка та встановлення Docker..."
    
    if command -v docker &> /dev/null; then
        log "Docker вже встановлений"
        return 0
    fi
    
    log "Встановлення Docker..."
    
    # Оновлення пакетів
    sudo apt-get update
    
    # Встановлення залежностей
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Додавання GPG ключа Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Додавання репозиторію Docker
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Встановлення Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Додавання користувача до групи docker
    sudo usermod -aG docker $USER
    
    log "Docker встановлений успішно ✓"
}

# Встановлення Docker Compose
install_docker_compose() {
    log "Перевірка та встановлення Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log "Docker Compose вже встановлений"
        return 0
    fi
    
    log "Встановлення Docker Compose..."
    
    # Завантаження Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Надання прав на виконання
    sudo chmod +x /usr/local/bin/docker-compose
    
    log "Docker Compose встановлений успішно ✓"
}

# Інтерактивне налаштування .env файлу
setup_env_interactive() {
    log "Налаштування змінних середовища..."
    
    # Створення .env файлу з прикладу
    if [[ ! -f .env ]]; then
        cp env.example .env
        log "Створено .env файл з прикладу"
    fi
    
    # Запит основного домену
    read -p "Введіть ваш домен (наприклад: matrix.example.com): " domain
    if [[ -z "$domain" ]]; then
        error "Домен не може бути порожнім"
        exit 1
    fi
    sed -i "s/your-domain.com/$domain/g" .env
    
    # Запит паролів
    read -s -p "Введіть пароль для бази даних PostgreSQL: " db_password
    echo
    if [[ -z "$db_password" ]]; then
        db_password=$(openssl rand -base64 32)
        log "Згенеровано випадковий пароль для бази даних"
    fi
    sed -i "s/your-db-password-here/$db_password/" .env
    
    read -s -p "Введіть пароль для Redis (Enter для автогенерації): " redis_password
    echo
    if [[ -z "$redis_password" ]]; then
        redis_password=$(openssl rand -base64 32)
        log "Згенеровано випадковий пароль для Redis"
    fi
    sed -i "s/your-redis-password-here/$redis_password/" .env
    
    read -s -p "Введіть пароль для Grafana (Enter для автогенерації): " grafana_password
    echo
    if [[ -z "$grafana_password" ]]; then
        grafana_password=$(openssl rand -base64 32)
        log "Згенеровано випадковий пароль для Grafana"
    fi
    sed -i "s/your-grafana-password-here/$grafana_password/" .env
    
    read -s -p "Введіть пароль для Matrix бота (Enter для автогенерації): " bot_password
    echo
    if [[ -z "$bot_password" ]]; then
        bot_password=$(openssl rand -base64 32)
        log "Згенеровано випадковий пароль для бота"
    fi
    sed -i "s/your-bot-password-here/$bot_password/" .env
    
    # Генерація секретних ключів
    local registration_secret=$(openssl rand -hex 32)
    local jwt_secret=$(openssl rand -hex 32)
    local encryption_key=$(openssl rand -hex 32)
    local backup_key=$(openssl rand -hex 32)
    local admin_secret=$(openssl rand -hex 32)
    
    # Оновлення .env файлу з секретами
    sed -i "s/your-secret-key-here/$registration_secret/" .env
    sed -i "s/your-jwt-secret-here/$jwt_secret/" .env
    sed -i "s/your-encryption-key-here/$encryption_key/" .env
    sed -i "s/your-backup-encryption-key-here/$backup_key/" .env
    sed -i "s/your-admin-secret-key-here/$admin_secret/" .env
    
    # Налаштування Cloudflare Tunnel
    read -p "Чи використовуєте ви Cloudflare Tunnel? (y/n): " use_tunnel
    if [[ $use_tunnel == "y" || $use_tunnel == "Y" ]]; then
        read -p "Введіть токен Cloudflare Tunnel: " tunnel_token
        if [[ -n "$tunnel_token" ]]; then
            sed -i "s/your-tunnel-token-here/$tunnel_token/" .env
            log "Cloudflare Tunnel налаштований"
        else
            sed -i "s/CLOUDFLARE_TUNNEL_ENABLED=true/CLOUDFLARE_TUNNEL_ENABLED=false/" .env
            log "Cloudflare Tunnel відключений"
        fi
    else
        sed -i "s/CLOUDFLARE_TUNNEL_ENABLED=true/CLOUDFLARE_TUNNEL_ENABLED=false/" .env
        log "Cloudflare Tunnel відключений"
    fi
    
    # Налаштування мостів
    echo "Виберіть мости для встановлення:"
    echo "1) Signal міст"
    echo "2) WhatsApp міст"
    echo "3) Discord міст"
    echo "4) Всі мости"
    echo "5) Без мостів"
    read -p "Виберіть опцію (1-5): " bridge_choice
    
    case $bridge_choice in
        1)
            sed -i "s/SIGNAL_BRIDGE_ENABLED=false/SIGNAL_BRIDGE_ENABLED=true/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
            log "Вибрано Signal міст"
            ;;
        2)
            sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=false/WHATSAPP_BRIDGE_ENABLED=true/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
            log "Вибрано WhatsApp міст"
            ;;
        3)
            sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=false/DISCORD_BRIDGE_ENABLED=true/" .env
            log "Вибрано Discord міст"
            ;;
        4)
            log "Вибрано всі мости"
            ;;
        5)
            sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
            log "Мости відключені"
            ;;
        *)
            error "Невірний вибір"
            exit 1
            ;;
    esac
    
    # Налаштування бекапів
    read -p "Чи вмикати автоматичні бекапи? (y/n): " enable_backup
    if [[ $enable_backup == "n" || $enable_backup == "N" ]]; then
        sed -i "s/BACKUP_ENABLED=true/BACKUP_ENABLED=false/" .env
        log "Автоматичні бекапи відключені"
    else
        read -p "Введіть кількість днів для зберігання бекапів (за замовчуванням 30): " backup_days
        if [[ -n "$backup_days" ]]; then
            sed -i "s/BACKUP_RETENTION_DAYS=30/BACKUP_RETENTION_DAYS=$backup_days/" .env
        fi
        log "Автоматичні бекапи налаштовані"
    fi
    
    # Налаштування Matrix бота
    read -p "Чи вмикати Matrix бота для сповіщень? (y/n): " enable_bot
    if [[ $enable_bot == "n" || $enable_bot == "N" ]]; then
        sed -i "s/MATRIX_BOT_ENABLED=true/MATRIX_BOT_ENABLED=false/" .env
        log "Matrix бот відключений"
    else
        read -p "Введіть ім'я користувача для бота (за замовчуванням system-bot): " bot_username
        if [[ -n "$bot_username" ]]; then
            sed -i "s/MATRIX_BOT_USERNAME=system-bot/MATRIX_BOT_USERNAME=$bot_username/" .env
        fi
        log "Matrix бот налаштований"
    fi
    
    log "Всі змінні середовища налаштовані успішно ✓"
}

# Створення конфігураційних файлів
create_configs() {
    log "Створення конфігураційних файлів..."
    
    # Створення директорій для конфігурацій
    mkdir -p config/{dendrite,bridges,nginx,grafana,prometheus}
    mkdir -p backup/{database,configs,uploads}
    
    # Створення конфігурації Dendrite
    cat > config/dendrite/dendrite.yaml << EOF
# Конфігурація Matrix Dendrite сервера
version: 1
global:
  server_name: ${DOMAIN:-your-domain.com}
  private_key: /etc/matrix/dendrite/signing.key
  trusted_third_party_id_servers:
    - matrix.org
    - vector.im

database:
  connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable

redis:
  address: ${REDIS_HOST:-redis}:${REDIS_PORT:-6379}
  password: ${REDIS_PASSWORD:-}

registration_shared_secret: ${REGISTRATION_SHARED_SECRET:-your-secret-key}

client_api:
  registration_disabled: false
  registration_shared_secret: ${REGISTRATION_SHARED_SECRET:-your-secret-key}

media_api:
  base_path: /var/lib/matrix/media

sync_api:
  database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable

room_server:
  database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable

federation_api:
  database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable

key_server:
  database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable

mscs:
  database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable

user_api:
  account_database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable
  device_database:
    connection_string: postgres://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD:-password}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable
EOF

    log "Конфігураційні файли створені ✓"
}

# Запуск сервісів
start_services() {
    log "Запуск сервісів..."
    
    # Перевірка наявності .env файлу
    if [[ ! -f ".env" ]]; then
        error "Файл .env не знайдено. Спочатку створіть конфігурацію."
        return 1
    fi
    
    # Завантаження змінних середовища
    source .env
    
    # Запуск сервісів через Docker Compose
    docker-compose up -d
    
    log "Сервіси запущені успішно ✓"
    log "Matrix сервер доступний за адресою: http://${DOMAIN:-localhost}:${DENDRITE_PORT:-8008}"
    log "Element Web клієнт: http://${DOMAIN:-localhost}"
    log "Адмін панель: http://${DOMAIN:-localhost}/admin"
}

# Перевірка статусу сервісів
check_status() {
    log "Перевірка статусу сервісів..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        error "Docker Compose не встановлений"
    fi
}

# Створення адміністратора
create_admin() {
    log "Створення адміністратора..."
    
    read -p "Введіть ім'я користувача адміністратора: " admin_user
    read -s -p "Введіть пароль: " admin_pass
    echo
    
    # Створення користувача через API
    curl -X POST "http://localhost:${DENDRITE_PORT:-8008}/_matrix/client/r0/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"auth\": {
                \"type\": \"m.login.dummy\"
            },
            \"initial_device_display_name\": \"Admin Device\",
            \"password\": \"$admin_pass\",
            \"username\": \"$admin_user\"
        }"
    
    log "Адміністратор створений успішно ✓"
}

# Головне меню
main_menu() {
    clear
    echo "=========================================="
    echo "    Matrix Dendrite Setup - Інсталятор"
    echo "=========================================="
    echo ""
    echo "1. Перевірити системні вимоги"
    echo "2. Встановити Docker"
    echo "3. Встановити Docker Compose"
    echo "4. Налаштувати змінні середовища"
    echo "5. Створити конфігурацію"
    echo "6. Запустити сервіси"
    echo "7. Перевірити статус"
    echo "8. Створити адміністратора"
    echo "9. Вихід"
    echo ""
    read -p "Виберіть опцію (1-9): " choice
    
    case $choice in
        1)
            check_system_requirements
            ;;
        2)
            install_docker
            ;;
        3)
            install_docker_compose
            ;;
        4)
            setup_env_interactive
            ;;
        5)
            create_configs
            ;;
        6)
            start_services
            ;;
        7)
            check_status
            ;;
        8)
            create_admin
            ;;
        9)
            log "До побачення!"
            exit 0
            ;;
        *)
            error "Невірний вибір"
            main_menu
            ;;
    esac
    
    echo ""
    read -p "Натисніть Enter для повернення до меню..."
    main_menu
}

# Головна функція
main() {
    log "Запуск Matrix Dendrite Setup інсталятора..."
    
    # Перевірка чи запущений скрипт з правильної директорії
    if [[ ! -f "README.md" ]]; then
        error "Скрипт повинен бути запущений з кореневої директорії проекту"
        exit 1
    fi
    
    # Запуск головного меню
    main_menu
}

# Запуск головної функції
main "$@" 