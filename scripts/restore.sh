#!/bin/sh
# Скрипт відновлення з резервної копії для Matrix Dendrite
# Автор: Matrix Setup Team

if [ -z "$1" ]; then
  echo "Вкажіть шлях до папки з бекапом!"
  exit 1
fi
BACKUP_DIR="$1"

# Відновлення Postgres
if [ -f "$BACKUP_DIR/postgres.sql" ]; then
  echo "[INFO] Відновлення бази даних Postgres..."
  PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" "$POSTGRES_DB" < "$BACKUP_DIR/postgres.sql"
else
  echo "[WARN] Бекап Postgres не знайдено"
fi

# Відновлення Redis
if [ -f "$BACKUP_DIR/redis.rdb" ]; then
  echo "[INFO] Відновлення Redis..."
  cp "$BACKUP_DIR/redis.rdb" /data/dump.rdb
  # Потрібен рестарт Redis для підхоплення дампу
else
  echo "[WARN] Бекап Redis не знайдено"
fi

# Відновлення конфігів
if [ -d "$BACKUP_DIR/config-matrix" ]; then
  echo "[INFO] Відновлення конфігурацій Matrix..."
  cp -r "$BACKUP_DIR/config-matrix"/* /etc/matrix/
fi
if [ -d "$BACKUP_DIR/config-nginx" ]; then
  echo "[INFO] Відновлення конфігурацій Nginx..."
  cp -r "$BACKUP_DIR/config-nginx"/* /etc/nginx/
fi

# Відновлення медіа
if [ -d "$BACKUP_DIR/media" ]; then
  echo "[INFO] Відновлення медіа..."
  cp -r "$BACKUP_DIR/media"/* /var/lib/matrix/media/
fi

echo "[INFO] Відновлення завершено!" 