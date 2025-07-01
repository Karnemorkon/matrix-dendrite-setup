#!/bin/bash

# Скрипт для збірки та публікації Docker образів
# Автор: Matrix Setup Team

set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логування
LOG_FILE="./logs/build-images.log"
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

log_step() {
    log "STEP: $1"
    echo -e "${BLUE}STEP: $1${NC}"
}

# Змінні
DOCKER_USERNAME=${DOCKER_USERNAME:-"your-dockerhub-username"}
REPO_NAME=${REPO_NAME:-"matrix-dendrite-setup"}
VERSION=${VERSION:-"latest"}
PUSH_IMAGES=${PUSH_IMAGES:-"false"}

# Перевірка Docker (тільки для збірки, не для довідки)
if [[ "$1" != "--help" ]]; then
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker не запущений"
        exit 1
    fi
fi

# Функція для збірки образу
build_image() {
    local name=$1
    local dockerfile_path=$2
    local context_path=$3
    
    log_step "Збірка образу $name..."
    
    local image_name="${DOCKER_USERNAME}/${REPO_NAME}-${name}"
    local full_tag="${image_name}:${VERSION}"
    local latest_tag="${image_name}:latest"
    
    # Збірка образу
    if docker build -t "$full_tag" -t "$latest_tag" -f "$dockerfile_path" "$context_path"; then
        log_info "Образ $name зібрано успішно: $full_tag"
        
        # Публікація на Docker Hub
        if [[ "$PUSH_IMAGES" == "true" ]]; then
            log_step "Публікація образу $name на Docker Hub..."
            if docker push "$full_tag" && docker push "$latest_tag"; then
                log_info "Образ $name опубліковано успішно"
            else
                log_error "Помилка публікації образу $name"
                return 1
            fi
        fi
    else
        log_error "Помилка збірки образу $name"
        return 1
    fi
}

# Головна функція
main() {
    log_info "Початок збірки Docker образів..."
    log_info "Docker Hub username: $DOCKER_USERNAME"
    log_info "Repository: $REPO_NAME"
    log_info "Version: $VERSION"
    log_info "Push images: $PUSH_IMAGES"
    
    # Перевірка наявності Dockerfile'ів
    if [[ ! -f "dashboard/admin-panel/Dockerfile" ]]; then
        log_error "Dockerfile адмін-панелі не знайдено"
        exit 1
    fi
    
    if [[ ! -f "config/bot/Dockerfile" ]]; then
        log_error "Dockerfile бота не знайдено"
        exit 1
    fi
    
    # Збірка адмін-панелі
    build_image "admin-panel" "dashboard/admin-panel/Dockerfile" "dashboard/admin-panel"
    
    # Збірка бота
    build_image "matrix-bot" "config/bot/Dockerfile" "config/bot"
    
    log_info "Збірка образів завершена!"
    
    if [[ "$PUSH_IMAGES" == "true" ]]; then
        log_info "Всі образи опубліковано на Docker Hub"
        echo ""
        echo "Образи доступні за адресами:"
        echo "  ${DOCKER_USERNAME}/${REPO_NAME}-admin-panel:${VERSION}"
        echo "  ${DOCKER_USERNAME}/${REPO_NAME}-matrix-bot:${VERSION}"
        echo ""
        echo "Для використання в docker-compose.yml:"
        echo "  image: ${DOCKER_USERNAME}/${REPO_NAME}-admin-panel:${VERSION}"
        echo "  image: ${DOCKER_USERNAME}/${REPO_NAME}-matrix-bot:${VERSION}"
    else
        log_info "Для публікації образів встановіть PUSH_IMAGES=true"
        echo ""
        echo "Локальні образи:"
        echo "  ${DOCKER_USERNAME}/${REPO_NAME}-admin-panel:${VERSION}"
        echo "  ${DOCKER_USERNAME}/${REPO_NAME}-matrix-bot:${VERSION}"
    fi
}

# Обробка аргументів командного рядка
while [[ $# -gt 0 ]]; do
    case $1 in
        --username)
            DOCKER_USERNAME="$2"
            shift 2
            ;;
        --repo)
            REPO_NAME="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --push)
            PUSH_IMAGES="true"
            shift
            ;;
        --help)
            echo "Використання: $0 [опції]"
            echo ""
            echo "Опції:"
            echo "  --username USERNAME  Docker Hub username (за замовчуванням: your-dockerhub-username)"
            echo "  --repo REPO          Repository name (за замовчуванням: matrix-dendrite-setup)"
            echo "  --version VERSION    Version tag (за замовчуванням: latest)"
            echo "  --push              Публікувати образи на Docker Hub"
            echo "  --help              Показати цю довідку"
            echo ""
            echo "Приклади:"
            echo "  $0 --username myuser --push"
            echo "  $0 --username myuser --repo my-matrix --version v1.0.0 --push"
            exit 0
            ;;
        *)
            log_error "Невідома опція: $1"
            exit 1
            ;;
    esac
done

# Запуск головної функції
main 