#!/bin/bash

# Скрипт для автоматичного оновлення контейнерів Matrix Dendrite
# Автор: Matrix Setup Team

set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Логування
LOG_FILE="/var/log/matrix/update.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO: $1"
    echo -e "${GREEN}INFO: $1${NC}"
}

log_warn() {
    log "WARN: $1"
    echo -e "${YELLOW}WARN: $1${NC}"
}

log_error() {
    log "ERROR: $1"
    echo -e "${RED}ERROR: $1${NC}"
}

# Перевірка чи запущений docker
if ! docker info >/dev/null 2>&1; then
    log_error "Docker не запущений"
    exit 1
fi

# Перевірка чи існує docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml не знайдено"
    exit 1
fi

log_info "Початок оновлення контейнерів..."

# Створення бекапу перед оновленням
log_info "Створення бекапу перед оновленням..."
if [ -f "scripts/backup.sh" ]; then
    bash scripts/backup.sh
    log_info "Бекап створено успішно"
else
    log_warn "Скрипт backup.sh не знайдено, пропускаємо створення бекапу"
fi

# Оновлення образів
log_info "Оновлення Docker образів..."
if docker-compose pull; then
    log_info "Образи оновлено успішно"
else
    log_error "Помилка оновлення образів"
    exit 1
fi

# Перезапуск контейнерів
log_info "Перезапуск контейнерів..."
if docker-compose up -d; then
    log_info "Контейнери перезапущено успішно"
else
    log_error "Помилка перезапуску контейнерів"
    exit 1
fi

# Перевірка стану після оновлення
log_info "Перевірка стану контейнерів..."
sleep 30

HEALTHY_COUNT=0
TOTAL_COUNT=0

for container in $(docker-compose ps -q); do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    if [ "$(docker inspect --format='{{.State.Status}}' "$container")" = "running" ]; then
        HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
    fi
done

log_info "Оновлення завершено: $HEALTHY_COUNT/$TOTAL_COUNT контейнерів працюють"

# Надсилання сповіщення через Matrix API (якщо доступно)
if [ -n "$MATRIX_BOT_URL" ]; then
    log_info "Надсилання сповіщення через Matrix..."
    curl -X POST "$MATRIX_BOT_URL/api/notifications/send" \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"🔄 Оновлення контейнерів завершено: $HEALTHY_COUNT/$TOTAL_COUNT працюють\",\"roomId\":\"$MATRIX_BOT_ROOM_ID\"}" \
        >/dev/null 2>&1 || log_warn "Не вдалося надіслати сповіщення"
fi

log_info "Оновлення завершено успішно!" 