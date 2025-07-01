FROM node:18-alpine

WORKDIR /app

# Копіювання package.json та package-lock.json
COPY package*.json ./

# Встановлення залежностей
RUN npm ci --only=production

# Копіювання вихідного коду
COPY . .

# Створення користувача для безпеки
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
RUN chown -R nodejs:nodejs /app
USER nodejs

# Відкриття порту
EXPOSE 3000

# Запуск додатку
CMD ["npm", "start"] 