FROM python:3.11-slim

WORKDIR /app

# Копіювання залежностей
COPY requirements.txt .

# Встановлення залежностей
RUN pip install --no-cache-dir -r requirements.txt

# Копіювання коду бота
COPY bot.py .

# Створення користувача для безпеки
RUN useradd -m -u 1001 bot
RUN chown -R bot:bot /app
USER bot

# Запуск бота
CMD ["python", "bot.py"] 