#!/bin/sh
# Скрипт резервного копіювання для Matrix Dendrite
# Зберігає дампи бази даних, Redis, конфіги та медіа
# Автор: Matrix Setup Team

BACKUP_DIR="/backup/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$BACKUP_DIR"

# Бекап Postgres
if [ -n "$POSTGRES_DB" ] && [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_PASSWORD" ]; then
  echo "[INFO] Бекап бази даних Postgres..."
  PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_DIR/postgres.sql"
else
  echo "[WARN] Пропущено бекап Postgres (немає змінних середовища)"
fi

# Бекап Redis
if [ -n "$REDIS_PASSWORD" ]; then
  echo "[INFO] Бекап Redis..."
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" save
  cp /data/dump.rdb "$BACKUP_DIR/redis.rdb"
else
  echo "[WARN] Пропущено бекап Redis (немає пароля)"
fi

# Бекап конфігів
echo "[INFO] Бекап конфігурацій..."
cp -r /etc/matrix "$BACKUP_DIR/config-matrix"
cp -r /etc/nginx "$BACKUP_DIR/config-nginx"

# Бекап медіа
echo "[INFO] Бекап медіа..."
cp -r /var/lib/matrix/media "$BACKUP_DIR/media"

# Очищення старих бекапів
if [ -n "$BACKUP_RETENTION_DAYS" ]; then
  echo "[INFO] Очищення бекапів старше $BACKUP_RETENTION_DAYS днів..."
  find /backup -maxdepth 1 -type d -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} \;
fi

echo "[INFO] Бекап завершено: $BACKUP_DIR" 