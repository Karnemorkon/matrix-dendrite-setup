#!/usr/bin/env python3
"""
Matrix Bot для керування Matrix Dendrite сервером
Автор: Matrix Setup Team
"""

import asyncio
import json
import logging
import os
import requests
from datetime import datetime
from typing import Dict, List, Optional, Any

import nio

# Налаштування логування
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- WHITELIST ---
# Дозволені кімнати та користувачі для керування ботом
ALLOWED_ROOMS = os.getenv('MATRIX_BOT_ROOM_ID', '').split(',')  # Можна перелік через кому
ALLOWED_USERS = os.getenv('MATRIX_BOT_ADMINS', '').split(',')   # user_id через кому

class MatrixAdminBot:
    def __init__(self):
        # Змінні середовища
        self.homeserver_url = os.getenv('MATRIX_HOMESERVER_URL', 'http://dendrite:8008')
        self.bot_username = os.getenv('MATRIX_BOT_USERNAME', 'system-bot')
        self.bot_password = os.getenv('MATRIX_BOT_PASSWORD', '')
        self.admin_room_id = os.getenv('MATRIX_BOT_ROOM_ID', '')
        self.admin_panel_url = os.getenv('ADMIN_PANEL_URL', 'http://admin-panel:3000')
        
        # Matrix клієнт
        self.client = None
        
        # Команди бота
        self.commands = {
            '/help': self.cmd_help,
            '/status': self.cmd_status,
            '/logs': self.cmd_logs,
            '/start': self.cmd_start,
            '/stop': self.cmd_stop,
            '/restart': self.cmd_restart,
            '/backup': self.cmd_backup,
            '/user': self.cmd_user,
            '/bridges': self.cmd_bridges,
            '/health': self.cmd_health,
            '/update': self.cmd_update,
        }

    async def start(self):
        """Запуск бота"""
        try:
            # Створення Matrix клієнта
            self.client = nio.AsyncClient(self.homeserver_url, self.bot_username)
            
            # Авторизація
            response = await self.client.login(self.bot_password)
            if response.status_code != 200:
                logger.error(f"Помилка авторизації: {response.status_code}")
                return
            
            logger.info(f"Бот {self.bot_username} успішно авторизований")
            
            # Реєстрація callback для обробки повідомлень
            self.client.add_event_callback(self.on_message, nio.RoomMessageText)
            
            # Синхронізація
            await self.client.sync()
            
            # Основний цикл
            while True:
                try:
                    await self.client.sync()
                    await asyncio.sleep(1)
                except Exception as e:
                    logger.error(f"Помилка синхронізації: {e}")
                    await asyncio.sleep(5)
                    
        except Exception as e:
            logger.error(f"Помилка запуску бота: {e}")

    async def on_message(self, room, event):
        """Обробка повідомлень"""
        try:
            # Перевірка чи це текстове повідомлення
            if hasattr(event, 'body'):
                body = event.body.strip()
            else:
                return
            
            # Перевірка чи це команда
            if not body.startswith('/'):
                return
            
            # --- Перевірка кімнати та користувача ---
            sender = event.sender
            if room.room_id not in ALLOWED_ROOMS:
                await self.send_message(room.room_id, '⛔️ Недозволена кімната для керування.')
                return
            if ALLOWED_USERS and sender not in ALLOWED_USERS:
                await self.send_message(room.room_id, '⛔️ Недостатньо прав для керування.')
                return
            
            # Парсинг команди
            parts = body.split()
            command = parts[0].lower()
            args = parts[1:] if len(parts) > 1 else []
            
            # Виконання команди
            if command in self.commands:
                await self.commands[command](room, args)
            else:
                await self.send_message(room.room_id, f"Невідома команда: {command}. Використайте /help для списку команд.")
                
        except Exception as e:
            logger.error(f"Помилка обробки повідомлення: {e}")
            await self.send_message(room.room_id, f"Помилка обробки команди: {e}")

    async def send_message(self, room_id: str, message: str):
        """Надсилання повідомлення"""
        try:
            if self.client is not None:
                await self.client.room_send(
                    room_id,
                    'm.room.message',
                    {
                        'msgtype': 'm.text',
                        'body': message
                    }
                )
        except Exception as e:
            logger.error(f"Помилка надсилання повідомлення: {e}")

    def call_admin_api(self, endpoint: str, method: str = 'GET', data: dict = None) -> dict:
        """Виклик API адмін-панелі"""
        try:
            url = f"{self.admin_panel_url}/api/{endpoint}"
            headers = {'Content-Type': 'application/json'}
            
            if method == 'GET':
                response = requests.get(url, headers=headers)
            elif method == 'POST':
                response = requests.post(url, headers=headers, json=data)
            elif method == 'DELETE':
                response = requests.delete(url, headers=headers)
            else:
                return {'success': False, 'error': 'Непідтримуваний метод'}
            
            return response.json()
        except Exception as e:
            return {'success': False, 'error': str(e)}

    # Команди бота
    async def cmd_help(self, room, args):
        """Допомога"""
        help_text = """
🤖 **Matrix Admin Bot - Довідка**

**Сервіси:**
• `/status` - статус всіх сервісів
• `/start <service>` - запустити сервіс
• `/stop <service>` - зупинити сервіс
• `/restart <service>` - перезапустити сервіс
• `/logs <service> [lines]` - логи сервісу (за замовчуванням 100 рядків)

**Бекапи:**
• `/backup create` - створити бекап
• `/backup list` - список бекапів
• `/backup restore <name>` - відновити бекап

**Користувачі:**
• `/user create <username> <password>` - створити користувача
• `/user list` - список користувачів
• `/user delete <username>` - видалити користувача

**Мости:**
• `/bridges status` - статус мостів
• `/bridges restart <name>` - перезапустити міст

**Система:**
• `/health` - перевірка здоров'я системи
• `/update` - оновлення контейнерів
• `/help` - ця довідка

**Приклади:**
• `/status`
• `/restart dendrite`
• `/logs postgres 50`
• `/backup create`
• `/user create john password123`
• `/update`
        """
        await self.send_message(room.room_id, help_text)

    async def cmd_status(self, room, args):
        """Статус сервісів"""
        try:
            response = self.call_admin_api('status')
            if response.get('success'):
                services = response.get('services', [])
                
                status_text = "📊 **Статус сервісів:**\n\n"
                for service in services:
                    status_emoji = "🟢" if service['status'] == 'running' else "🔴"
                    status_text += f"{status_emoji} **{service['name']}**: {service['status']}\n"
                
                await self.send_message(room.room_id, status_text)
            else:
                await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def cmd_logs(self, room, args):
        """Логи сервісу"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/logs <service> [lines]`")
            return
        
        service = args[0]
        lines = args[1] if len(args) > 1 else '100'
        
        try:
            response = self.call_admin_api(f'logs/{service}?lines={lines}')
            if response.get('success'):
                logs = response.get('logs', '')
                # Обмежуємо довжину логів
                if len(logs) > 2000:
                    logs = logs[:2000] + "\n... (обрізано)"
                
                await self.send_message(room.room_id, f"📋 **Логи {service}:**\n```\n{logs}\n```")
            else:
                await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def cmd_start(self, room, args):
        """Запуск сервісу"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/start <service>`")
            return
        
        service = args[0]
        try:
            response = self.call_admin_api(f'service/start/{service}', 'POST')
            if response.get('success'):
                await self.send_message(room.room_id, f"✅ {response.get('message', f'Сервіс {service} запущено')}")
            else:
                await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def cmd_stop(self, room, args):
        """Зупинка сервісу"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/stop <service>`")
            return
        
        service = args[0]
        try:
            response = self.call_admin_api(f'service/stop/{service}', 'POST')
            if response.get('success'):
                await self.send_message(room.room_id, f"✅ {response.get('message', f'Сервіс {service} зупинено')}")
            else:
                await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def cmd_restart(self, room, args):
        """Перезапуск сервісу"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/restart <service>`")
            return
        
        service = args[0]
        try:
            response = self.call_admin_api(f'service/restart/{service}', 'POST')
            if response.get('success'):
                await self.send_message(room.room_id, f"✅ {response.get('message', f'Сервіс {service} перезапущено')}")
            else:
                await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def cmd_backup(self, room, args):
        """Керування бекапами"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/backup <create|list|restore> [name]`")
            return
        
        action = args[0]
        
        if action == 'create':
            try:
                response = self.call_admin_api('backups/create', 'POST')
                if response.get('success'):
                    await self.send_message(room.room_id, f"✅ {response.get('message', 'Бекап створено')}")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        elif action == 'list':
            try:
                response = self.call_admin_api('backups')
                if response.get('success'):
                    backups = response.get('backups', [])
                    if backups:
                        backup_text = "📦 **Список бекапів:**\n\n"
                        for backup in backups[:10]:  # Показуємо тільки 10 останніх
                            backup_text += f"• **{backup['name']}** ({backup['size']} байт)\n"
                        await self.send_message(room.room_id, backup_text)
                    else:
                        await self.send_message(room.room_id, "📦 Бекапів не знайдено")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        elif action == 'restore':
            if len(args) < 2:
                await self.send_message(room.room_id, "❌ Використання: `/backup restore <name>`")
                return
            
            backup_name = args[1]
            try:
                response = self.call_admin_api(f'backups/restore/{backup_name}', 'POST')
                if response.get('success'):
                    await self.send_message(room.room_id, f"✅ {response.get('message', 'Бекап відновлено')}")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        else:
            await self.send_message(room.room_id, "❌ Невідома дія. Використання: `/backup <create|list|restore> [name]`")

    async def cmd_user(self, room, args):
        """Керування користувачами"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/user <create|list|delete> [username] [password]`")
            return
        
        action = args[0]
        
        if action == 'create':
            if len(args) < 3:
                await self.send_message(room.room_id, "❌ Використання: `/user create <username> <password>`")
                return
            
            username = args[1]
            password = args[2]
            
            try:
                response = self.call_admin_api('users/create', 'POST', {
                    'username': username,
                    'password': password
                })
                if response.get('success'):
                    await self.send_message(room.room_id, f"✅ Користувача {username} створено")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        elif action == 'list':
            try:
                response = self.call_admin_api('users')
                if response.get('success'):
                    users = response.get('users', [])
                    if users:
                        user_text = "👥 **Список користувачів:**\n\n"
                        for user in users:
                            user_text += f"• **{user['username']}**\n"
                        await self.send_message(room.room_id, user_text)
                    else:
                        await self.send_message(room.room_id, "👥 Користувачів не знайдено")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        elif action == 'delete':
            if len(args) < 2:
                await self.send_message(room.room_id, "❌ Використання: `/user delete <username>`")
                return
            
            username = args[1]
            try:
                response = self.call_admin_api(f'users/{username}', 'DELETE')
                if response.get('success'):
                    await self.send_message(room.room_id, f"✅ Користувача {username} видалено")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        else:
            await self.send_message(room.room_id, "❌ Невідома дія. Використання: `/user <create|list|delete> [username] [password]`")

    async def cmd_bridges(self, room, args):
        """Керування мостами"""
        if len(args) < 1:
            await self.send_message(room.room_id, "❌ Використання: `/bridges <status|restart> [name]`")
            return
        
        action = args[0]
        
        if action == 'status':
            try:
                response = self.call_admin_api('bridges/status')
                if response.get('success'):
                    bridges = response.get('bridges', [])
                    if bridges:
                        bridge_text = "🌉 **Статус мостів:**\n\n"
                        for bridge in bridges:
                            status_emoji = "🟢" if bridge['status'] == 'running' else "🔴"
                            bridge_text += f"{status_emoji} **{bridge['name']}**: {bridge['status']}\n"
                        await self.send_message(room.room_id, bridge_text)
                    else:
                        await self.send_message(room.room_id, "🌉 Мостів не знайдено")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        elif action == 'restart':
            if len(args) < 2:
                await self.send_message(room.room_id, "❌ Використання: `/bridges restart <name>`")
                return
            
            bridge_name = args[1]
            try:
                response = self.call_admin_api(f'bridges/restart/{bridge_name}', 'POST')
                if response.get('success'):
                    await self.send_message(room.room_id, f"✅ {response.get('message', f'Міст {bridge_name} перезапущено')}")
                else:
                    await self.send_message(room.room_id, f"❌ Помилка: {response.get('error', 'Невідома помилка')}")
            except Exception as e:
                await self.send_message(room.room_id, f"❌ Помилка: {e}")
        
        else:
            await self.send_message(room.room_id, "❌ Невідома дія. Використання: `/bridges <status|restart> [name]`")

    async def cmd_health(self, room, args):
        """Перевірка здоров'я системи"""
        try:
            response = self.call_admin_api('health')
            if response.get('success'):
                health = response.get('health', [])
                summary = response.get('summary', {})
                
                healthy = summary.get('healthy', 0)
                unhealthy = summary.get('unhealthy', 0)
                total = summary.get('total', 0)
                
                message = f"🏥 **Healthcheck результат:**\n\n"
                message += f"✅ Здорові: {healthy}\n"
                message += f"❌ Нездорові: {unhealthy}\n"
                message += f"📊 Всього: {total}\n\n"
                
                if unhealthy > 0:
                    unhealthy_services = [h['name'] for h in health if not h.get('healthy')]
                    message += f"⚠️ **Нездорові сервіси:**\n"
                    for service in unhealthy_services:
                        message += f"• {service}\n"
                else:
                    message += "🎉 Всі сервіси працюють нормально!"
                
                await self.send_message(room.room_id, message)
            else:
                await self.send_message(room.room_id, f"❌ Помилка healthcheck: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def cmd_update(self, room, args):
        """Оновлення контейнерів"""
        try:
            await self.send_message(room.room_id, "🔄 Початок оновлення контейнерів...")
            
            response = self.call_admin_api('update', method='POST')
            if response.get('success'):
                await self.send_message(room.room_id, "✅ Контейнери оновлено успішно!")
                
                # Отримуємо оновлений healthcheck
                health_response = self.call_admin_api('health')
                if health_response.get('success'):
                    summary = health_response.get('summary', {})
                    healthy = summary.get('healthy', 0)
                    total = summary.get('total', 0)
                    await self.send_message(room.room_id, f"📊 Статус після оновлення: {healthy}/{total} контейнерів працюють")
            else:
                await self.send_message(room.room_id, f"❌ Помилка оновлення: {response.get('error', 'Невідома помилка')}")
        except Exception as e:
            await self.send_message(room.room_id, f"❌ Помилка: {e}")

    async def send_notification(self, message: str, room_id: str = None):
        """Надсилання сповіщення через адмін-панель"""
        try:
            target_room = room_id or self.admin_room_id
            if not target_room:
                logger.warning("Не вказано room_id для сповіщення")
                return
            
            response = self.call_admin_api('notifications/send', method='POST', data={
                'message': message,
                'roomId': target_room
            })
            
            if response and response.get('success'):
                logger.info(f"Сповіщення надіслано: {message}")
            else:
                logger.error(f"Помилка надсилання сповіщення: {response.get('error') if response else 'Невідома помилка'}")
        except Exception as e:
            logger.error(f"Помилка надсилання сповіщення: {e}")

    async def healthcheck_notification(self):
        """Автоматична перевірка здоров'я з сповіщенням"""
        try:
            response = self.call_admin_api('health')
            if response.get('success'):
                summary = response.get('summary', {})
                unhealthy = summary.get('unhealthy', 0)
                
                if unhealthy > 0:
                    health = response.get('health', [])
                    unhealthy_services = [h['name'] for h in health if not h.get('healthy')]
                    
                    message = f"⚠️ **Healthcheck попередження:**\n"
                    message += f"Знайдено {unhealthy} нездорових сервісів:\n"
                    for service in unhealthy_services:
                        message += f"• {service}\n"
                    
                    await self.send_notification(message)
                    logger.warning(f"Healthcheck: знайдено {unhealthy} нездорових сервісів")
        except Exception as e:
            logger.error(f"Помилка healthcheck notification: {e}")

    async def backup_notification(self, action: str, details: str = ""):
        """Сповіщення про бекап"""
        try:
            message = f"💾 **Бекап {action}:**\n{details}"
            await self.send_notification(message)
        except Exception as e:
            logger.error(f"Помилка backup notification: {e}")

    async def service_notification(self, service: str, action: str, status: str):
        """Сповіщення про зміну стану сервісу"""
        try:
            emoji = "✅" if status == "success" else "❌"
            message = f"{emoji} **Сервіс {service} {action}:** {status}"
            await self.send_notification(message)
        except Exception as e:
            logger.error(f"Помилка service notification: {e}")

    async def background_tasks(self):
        """Фонові завдання"""
        while True:
            try:
                # Healthcheck кожні 5 хвилин
                await self.healthcheck_notification()
                await asyncio.sleep(300)  # 5 хвилин
            except Exception as e:
                logger.error(f"Помилка фонового завдання: {e}")
                await asyncio.sleep(60)

# Головна функція
async def main():
    bot = MatrixAdminBot()
    
    # Запуск бота та фонових задач
    await asyncio.gather(
        bot.start(),
        bot.background_tasks()
    )

if __name__ == "__main__":
    asyncio.run(main()) 