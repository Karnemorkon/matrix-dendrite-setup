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

# Визначення дистрибутиву
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        VERSION=$(cat /etc/debian_version)
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        DISTRO=$(echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]')
        VERSION=$DISTRIB_RELEASE
    else
        error "Не вдалося визначити дистрибутив"
        exit 1
    fi
    
    log "Виявлено дистрибутив: $DISTRO $VERSION"
}

# Встановлення Docker
install_docker() {
    log "Перевірка та встановлення Docker..."
    
    if command -v docker &> /dev/null; then
        log "Docker вже встановлений"
        return 0
    fi
    
    # Визначення дистрибутиву
    detect_distribution
    
    log "Встановлення Docker для $DISTRO..."
    
    # Очищення старих репозиторіїв Docker, якщо вони існують
    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        log "Видалення старого репозиторію Docker..."
        sudo rm -f /etc/apt/sources.list.d/docker.list
    fi
    
    # Оновлення пакетів
    sudo apt-get update
    
    # Встановлення залежностей
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Встановлення Docker в залежності від дистрибутиву
    case $DISTRO in
        "ubuntu")
            log "Встановлення Docker для Ubuntu..."
            # Додавання GPG ключа Docker
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Додавання репозиторію Docker для Ubuntu
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Встановлення Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        "debian")
            log "Встановлення Docker для Debian..."
            # Додавання GPG ключа Docker
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Додавання репозиторію Docker для Debian
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Встановлення Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        *)
            log "Використання стандартного пакету Docker для $DISTRO..."
            sudo apt-get install -y docker.io
            ;;
    esac
    
    # Додавання користувача до групи docker
    sudo usermod -aG docker $USER
    
    # Запуск та вмикання Docker сервісу
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Перевірка та виправлення прав доступу
    if ! docker info &> /dev/null; then
        warn "Docker потребує перезавантаження сесії або перезапуску системи"
        warn "Або запустіть: newgrp docker"
        
        # Автоматичне виправлення прав
        fix_docker_permissions
    fi
    
    log "Docker встановлений успішно ✓"
}

# Встановлення Docker Compose
install_docker_compose() {
    log "Перевірка та встановлення Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log "Docker Compose вже встановлений"
        return 0
    fi
    
    # Визначення дистрибутиву
    detect_distribution
    
    log "Встановлення Docker Compose для $DISTRO..."
    
    # Встановлення Docker Compose в залежності від дистрибутиву
    case $DISTRO in
        "ubuntu"|"debian")
            # Спробувати встановити через apt
            if sudo apt-get install -y docker-compose-plugin; then
                log "Docker Compose встановлений через apt"
                # Створити символічне посилання для зворотної сумісності
                sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
            else
                log "Встановлення Docker Compose з GitHub..."
                # Завантаження Docker Compose
                sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                
                # Надання прав на виконання
                sudo chmod +x /usr/local/bin/docker-compose
            fi
            ;;
        *)
            log "Встановлення Docker Compose з GitHub..."
            # Завантаження Docker Compose
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            
            # Надання прав на виконання
            sudo chmod +x /usr/local/bin/docker-compose
            ;;
    esac
    
    log "Docker Compose встановлений успішно ✓"
}

# Виправлення прав доступу Docker
fix_docker_permissions() {
    log "Перевірка прав доступу Docker..."
    
    if ! docker info &> /dev/null; then
        warn "Проблема з правами доступу Docker"
        
        # Спробувати виправити права
        sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
        
        # Перезапустити Docker сервіс
        sudo systemctl restart docker
        
        # Оновити групи користувача
        newgrp docker <<< "echo 'Групи оновлено'" || true
        
        if docker info &> /dev/null; then
            log "Права доступу виправлено ✓"
        else
            warn "Потрібно перезавантажити сесію або систему"
            warn "Запустіть: newgrp docker"
        fi
    else
        log "Права доступу Docker в порядку ✓"
    fi
}

# Інтерактивне налаштування .env файлу
setup_env_interactive() {
    clear
    echo "=========================================="
    echo "    🌐 Налаштування Matrix сервера"
    echo "=========================================="
    echo ""
    echo "Цей крок налаштує всі необхідні параметри для роботи Matrix сервера:"
    echo "• Домен та мережеві налаштування"
    echo "• Паролі для сервісів"
    echo "• Мости для зовнішніх месенджерів"
    echo "• Автоматичні бекапи"
    echo "• Системний бот"
    echo ""
    echo "💡 Поради:"
    echo "• Використовуйте надійні паролі"
    echo "• Зберігайте паролі в безпечному місці"
    echo "• Для тестування можна використовувати localhost"
    echo ""
    log "Початок налаштування змінних середовища..."
    
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
    echo ""
    echo "🌉 Налаштування мостів для зовнішніх месенджерів:"
    echo "Мости дозволяють користувачам спілкуватися через Matrix з користувачами інших платформ."
    echo ""
    
    # Інтерактивний вибір мостів
    echo "📱 Доступні мости:"
    echo "1) 📞 Signal міст - для спілкування з користувачами Signal"
    echo "   • Потребує налаштування через веб-інтерфейс"
    echo "   • Порт: 29328"
    echo ""
    echo "2) 💬 WhatsApp міст - для спілкування з користувачами WhatsApp"
    echo "   • Потребує QR-код для авторизації"
    echo "   • Порт: 29329"
    echo ""
    echo "3) 🎮 Discord міст - для спілкування з користувачами Discord"
    echo "   • Потребує токен Discord бота"
    echo "   • Порт: 29330"
    echo ""
    
    # Вибір режиму
    echo "🔧 Режими встановлення:"
    echo "4) ✅ Всі мости - встановити всі доступні мости"
    echo "5) ❌ Без мостів - не встановлювати жодного моста"
    echo "6) 🎯 Вибрати окремо - налаштувати кожен міст індивідуально"
    echo ""
    
    read -p "Виберіть режим (1-6): " bridge_mode
    
    case $bridge_mode in
        1)
            # Тільки Signal
            sed -i "s/SIGNAL_BRIDGE_ENABLED=false/SIGNAL_BRIDGE_ENABLED=true/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
            log "✅ Вибрано Signal міст"
            ;;
        2)
            # Тільки WhatsApp
            sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=false/WHATSAPP_BRIDGE_ENABLED=true/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
            log "✅ Вибрано WhatsApp міст"
            ;;
        3)
            # Тільки Discord
            sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=false/DISCORD_BRIDGE_ENABLED=true/" .env
            log "✅ Вибрано Discord міст"
            ;;
        4)
            # Всі мости
            log "✅ Вибрано всі мости"
            ;;
        5)
            # Без мостів
            sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
            sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
            sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
            log "❌ Мости відключені"
            ;;
        6)
            # Індивідуальний вибір
            echo ""
            echo "🎯 Індивідуальний вибір мостів:"
            
            read -p "Встановити Signal міст? (y/n): " signal_choice
            if [[ $signal_choice == "y" || $signal_choice == "Y" ]]; then
                sed -i "s/SIGNAL_BRIDGE_ENABLED=false/SIGNAL_BRIDGE_ENABLED=true/" .env
                echo "✅ Signal міст включений"
            else
                sed -i "s/SIGNAL_BRIDGE_ENABLED=true/SIGNAL_BRIDGE_ENABLED=false/" .env
                echo "❌ Signal міст відключений"
            fi
            
            read -p "Встановити WhatsApp міст? (y/n): " whatsapp_choice
            if [[ $whatsapp_choice == "y" || $whatsapp_choice == "Y" ]]; then
                sed -i "s/WHATSAPP_BRIDGE_ENABLED=false/WHATSAPP_BRIDGE_ENABLED=true/" .env
                echo "✅ WhatsApp міст включений"
            else
                sed -i "s/WHATSAPP_BRIDGE_ENABLED=true/WHATSAPP_BRIDGE_ENABLED=false/" .env
                echo "❌ WhatsApp міст відключений"
            fi
            
            read -p "Встановити Discord міст? (y/n): " discord_choice
            if [[ $discord_choice == "y" || $discord_choice == "Y" ]]; then
                sed -i "s/DISCORD_BRIDGE_ENABLED=false/DISCORD_BRIDGE_ENABLED=true/" .env
                echo "✅ Discord міст включений"
            else
                sed -i "s/DISCORD_BRIDGE_ENABLED=true/DISCORD_BRIDGE_ENABLED=false/" .env
                echo "❌ Discord міст відключений"
            fi
            
            log "🎯 Індивідуальний вибір мостів завершено"
            ;;
        *)
            error "❌ Невірний вибір. Використовую налаштування за замовчуванням (всі мости)"
            ;;
    esac
    
    # Налаштування бекапів
    echo ""
    echo "💾 Налаштування автоматичних бекапів:"
    echo "Автоматичні бекапи зберігають конфігурації, бази даних та завантажені файли."
    echo "Рекомендується для захисту даних у випадку збою системи."
    echo ""
    
    read -p "Чи вмикати автоматичні бекапи? (y/n): " enable_backup
    if [[ $enable_backup == "n" || $enable_backup == "N" ]]; then
        sed -i "s/BACKUP_ENABLED=true/BACKUP_ENABLED=false/" .env
        log "❌ Автоматичні бекапи відключені"
    else
        echo ""
        echo "📅 Налаштування періоду зберігання:"
        echo "• Короткий період (1-7 днів) - економить місце"
        echo "• Середній період (7-30 днів) - баланс між безпекою та місцем"
        echo "• Довгий період (30+ днів) - максимальна безпека"
        echo ""
        read -p "Введіть кількість днів для зберігання бекапів (за замовчуванням 30): " backup_days
        if [[ -n "$backup_days" ]]; then
            sed -i "s/BACKUP_RETENTION_DAYS=30/BACKUP_RETENTION_DAYS=$backup_days/" .env
            log "✅ Автоматичні бекапи налаштовані на $backup_days днів"
        else
            log "✅ Автоматичні бекапи налаштовані на 30 днів (за замовчуванням)"
        fi
    fi
    
    # Налаштування Matrix бота
    echo ""
    echo "🤖 Налаштування Matrix бота:"
    echo "Matrix бот може надсилати сповіщення про стан сервісів, помилки та важливі події."
    echo "Корисно для моніторингу та адміністрування сервера."
    echo ""
    
    read -p "Чи вмикати Matrix бота для сповіщень? (y/n): " enable_bot
    if [[ $enable_bot == "n" || $enable_bot == "N" ]]; then
        sed -i "s/MATRIX_BOT_ENABLED=true/MATRIX_BOT_ENABLED=false/" .env
        log "❌ Matrix бот відключений"
    else
        echo ""
        echo "👤 Налаштування бота:"
        echo "• Бот буде створений як окремий користувач на сервері"
        echo "• Він може надсилати повідомлення в кімнати для сповіщень"
        echo "• Корисний для моніторингу стану сервісів"
        echo ""
        read -p "Введіть ім'я користувача для бота (за замовчуванням system-bot): " bot_username
        if [[ -n "$bot_username" ]]; then
            sed -i "s/MATRIX_BOT_USERNAME=system-bot/MATRIX_BOT_USERNAME=$bot_username/" .env
            log "✅ Matrix бот налаштований з ім'ям: $bot_username"
        else
            log "✅ Matrix бот налаштований з ім'ям: system-bot"
        fi
    fi
    
    log "Всі змінні середовища налаштовані успішно ✓"
}

# Створення конфігураційних файлів
create_configs() {
    log "Створення конфігураційних файлів..."
    
    # Завантаження змінних середовища
    if [[ -f ".env" ]]; then
        source .env
    else
        error "Файл .env не знайдено. Спочатку створіть конфігурацію."
        return 1
    fi
    
    # Створення директорій для конфігурацій
    mkdir -p config/{dendrite,bridges,nginx,grafana,prometheus}
    mkdir -p backup/{database,configs,uploads}
    
    # Створення конфігурації Dendrite
    cat > config/dendrite/dendrite.yaml << EOF
# Конфігурація Matrix Dendrite сервера
version: 2

global:
  server_name: ${DOMAIN:-localhost}
  private_key: /etc/matrix/dendrite/signing.key
  trusted_third_party_id_servers:
    - matrix.org
    - vector.im
  disable_federation: false
  presence:
    enable_inbound: false
    enable_outbound: false
  report_stats:
    enabled: false
  server_notices:
    enabled: false
  metrics:
    enabled: false
  dns_cache:
    enabled: false
  database:
    connection_string: postgresql://${POSTGRES_USER:-dendrite}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-dendrite}?sslmode=disable
    max_open_conns: 90
    max_idle_conns: 5
    conn_max_lifetime: -1
  cache:
    max_size_estimated: 1gb
    max_age: 1h

client_api:
  registration_disabled: false
  registration_shared_secret: ${REGISTRATION_SHARED_SECRET}
  guests_disabled: true
  enable_registration_captcha: false
  rate_limiting:
    enabled: true
    threshold: 20
    cooloff_ms: 500

federation_api:
  send_max_retries: 16
  disable_tls_validation: false
  disable_http_keepalives: false
  prefer_direct_fetch: false

media_api:
  base_path: /var/lib/matrix/media
  max_file_size_bytes: 10485760
  dynamic_thumbnails: false
  max_thumbnail_generators: 10
  thumbnail_sizes:
    - width: 32
      height: 32
      method: crop
    - width: 96
      height: 96
      method: crop
    - width: 640
      height: 480
      method: scale

sync_api:
  search:
    enabled: false
    index_path: "./searchindex"
    language: "en"

user_api:
  bcrypt_cost: 10
  auto_join_rooms: []

mscs:
  mscs: []

logging:
  - type: std
    level: info
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
    echo "📋 Доступні опції:"
    echo ""
    echo "🔧 Системні налаштування:"
    echo "1. ✅ Перевірити системні вимоги (Docker, права доступу)"
    echo "2. 🐳 Встановити Docker (контейнеризація)"
    echo "3. 🚀 Встановити Docker Compose (оркестрація сервісів)"
    echo "4. 🔐 Виправити права Docker (безпека доступу)"
    echo ""
    echo "⚙️  Налаштування сервера:"
    echo "5. 🌐 Налаштувати змінні середовища (домен, паролі, мости)"
    echo "6. 📝 Створити конфігурацію (файли налаштувань)"
    echo "7. ▶️  Запустити сервіси (Matrix, мости, панелі)"
    echo "8. 📊 Перевірити статус (стан всіх сервісів)"
    echo "9. 👤 Створити адміністратора (перший користувач)"
    echo ""
    echo "0. 🚪 Вихід"
    echo ""
    read -p "Виберіть опцію (0-9): " choice
    
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
            fix_docker_permissions
            ;;
        5)
            setup_env_interactive
            ;;
        6)
            create_configs
            ;;
        7)
            start_services
            ;;
        8)
            check_status
            ;;
        9)
            create_admin
            ;;
        0)
            log "До побачення!"
            exit 0
            ;;
        *)
            error "Невірний вибір. Введіть число від 0 до 9"
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
    
    # Автоматичне встановлення залежностей
    log "=== Автоматичне встановлення залежностей ==="
    
    # Крок 1: Перевірка системних вимог
    log "Крок 1: Перевірка системних вимог..."
    check_system_requirements
    
    # Крок 2: Встановлення Docker
    log "Крок 2: Встановлення Docker..."
    install_docker
    
    # Крок 3: Встановлення Docker Compose
    log "Крок 3: Встановлення Docker Compose..."
    install_docker_compose
    
    # Крок 4: Виправлення прав Docker
    log "Крок 4: Виправлення прав Docker..."
    fix_docker_permissions
    
    log "✅ Залежності встановлено успішно!"
    
    # Перехід до інтерактивних налаштувань
    log "=== Інтерактивні налаштування ==="
    setup_env_interactive
    create_configs
    start_services
    check_status
    create_admin
    
    log "✅ Matrix Dendrite Setup готовий до використання!"
    log "Доступні сервіси:"
    log "- Matrix сервер: http://localhost:8008"
    log "- Element Web: http://localhost"
    log "- Адмін панель: http://localhost:8080"
    log "- Grafana: http://localhost:3000"
}

# Запуск головної функції
main "$@" 