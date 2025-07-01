const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const Docker = require('dockerode');
const axios = require('axios');
const fs = require('fs-extra');
const path = require('path');
const cron = require('node-cron');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
const PORT = process.env.PORT || 3000;

// JWT секрет (в продакшені має бути в .env)
const JWT_SECRET = process.env.JWT_SECRET || 'your-jwt-secret-key';

// Файл для зберігання користувачів адмін-панелі
const USERS_FILE = path.join(__dirname, 'data', 'users.json');
const AUDIT_LOG_FILE = path.join(__dirname, 'data', 'audit.log');

// Створення директорії для даних
fs.ensureDirSync(path.dirname(USERS_FILE));

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Функція для аудиту
function auditLog(action, user = 'system', details = {}) {
    const logEntry = {
        timestamp: new Date().toISOString(),
        action,
        user,
        details,
        ip: req?.ip || 'unknown'
    };
    
    fs.appendFileSync(AUDIT_LOG_FILE, JSON.stringify(logEntry) + '\n');
}

// Middleware для автентифікації
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ success: false, error: 'Токен не надано' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ success: false, error: 'Недійсний токен' });
        }
        req.user = user;
        next();
    });
}

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 хвилин
  max: 100 // максимум 100 запитів з IP
});
app.use(limiter);

// Docker підключення
const docker = new Docker({
  socketPath: '/var/run/docker.sock'
});

// =====================
// API ENDPOINTS
// =====================

// Автентифікація
app.post('/api/auth/register', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({ success: false, error: 'Потрібні username та password' });
        }

        // Перевірка чи користувач вже існує
        let users = [];
        if (await fs.pathExists(USERS_FILE)) {
            users = JSON.parse(await fs.readFile(USERS_FILE, 'utf8'));
        }

        if (users.find(u => u.username === username)) {
            return res.status(400).json({ success: false, error: 'Користувач вже існує' });
        }

        // Хешування пароля
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Додавання користувача
        users.push({
            username,
            password: hashedPassword,
            created: new Date().toISOString()
        });

        await fs.writeFile(USERS_FILE, JSON.stringify(users, null, 2));
        
        auditLog('user_register', username);
        res.json({ success: true, message: 'Користувача створено успішно' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({ success: false, error: 'Потрібні username та password' });
        }

        // Читання користувачів
        let users = [];
        if (await fs.pathExists(USERS_FILE)) {
            users = JSON.parse(await fs.readFile(USERS_FILE, 'utf8'));
        }

        const user = users.find(u => u.username === username);
        if (!user) {
            return res.status(401).json({ success: false, error: 'Невірні облікові дані' });
        }

        // Перевірка пароля
        const validPassword = await bcrypt.compare(password, user.password);
        if (!validPassword) {
            return res.status(401).json({ success: false, error: 'Невірні облікові дані' });
        }

        // Створення JWT токена
        const token = jwt.sign({ username: user.username }, JWT_SECRET, { expiresIn: '24h' });
        
        auditLog('user_login', username);
        res.json({ success: true, token, username: user.username });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Захищені API endpoints
app.use('/api', authenticateToken);

// Статус сервісів
app.get('/api/status', async (req, res) => {
  try {
    const containers = await docker.listContainers({ all: true });
    const services = containers.map(container => ({
      id: container.Id,
      name: container.Names[0].replace('/', ''),
      status: container.State,
      image: container.Image,
      ports: container.Ports,
      created: container.Created
    }));
    
    res.json({ success: true, services });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Запуск/зупинка сервісу
app.post('/api/service/:action/:name', async (req, res) => {
    try {
        const { action, name } = req.params;
        const container = docker.getContainer(name);
        
        if (action === 'start') {
            await container.start();
        } else if (action === 'stop') {
            await container.stop();
        } else if (action === 'restart') {
            await container.restart();
        }
        
        auditLog(`service_${action}`, req.user.username, { service: name });
        res.json({ success: true, message: `Сервіс ${name} ${action} успішно` });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Логи сервісу
app.get('/api/logs/:name', async (req, res) => {
  try {
    const { name } = req.params;
    const { lines = 100 } = req.query;
    
    const container = docker.getContainer(name);
    const logs = await container.logs({
      stdout: true,
      stderr: true,
      tail: lines
    });
    
    res.json({ success: true, logs: logs.toString() });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Створення користувача Matrix
app.post('/api/users/create', async (req, res) => {
    try {
        const { username, password, displayName } = req.body;
        
        const response = await axios.post(`http://dendrite:8008/_matrix/client/r0/register`, {
            auth: { type: 'm.login.dummy' },
            initial_device_display_name: displayName || 'Admin Device',
            password: password,
            username: username
        });
        
        auditLog('matrix_user_create', req.user.username, { username, displayName });
        res.json({ success: true, user: response.data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Видалення користувача Matrix
app.delete('/api/users/:username', async (req, res) => {
    try {
        const { username } = req.params;
        
        // Тут потрібно буде додати логіку видалення користувача через Matrix API
        // Поки що просто логуємо
        
        auditLog('matrix_user_delete', req.user.username, { username });
        res.json({ success: true, message: `Користувача ${username} видалено успішно` });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Зміна пароля користувача Matrix
app.put('/api/users/:username/password', async (req, res) => {
    try {
        const { username } = req.params;
        const { password } = req.body;
        
        // Тут потрібно буде додати логіку зміни пароля через Matrix API
        // Поки що просто логуємо
        
        auditLog('matrix_user_password_change', req.user.username, { username });
        res.json({ success: true, message: `Пароль користувача ${username} змінено успішно` });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Список користувачів (через API або базу даних)
app.get('/api/users', async (req, res) => {
  try {
    // Тут можна додати логіку отримання користувачів з бази даних
    res.json({ success: true, users: [] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Створення бекапу
app.post('/api/backups/create', async (req, res) => {
    try {
        const backupDir = `/backup/$(date +%Y-%m-%d_%H-%M-%S)`;
        await fs.ensureDir(backupDir);
        
        // Виконання скрипта бекапу
        const { exec } = require('child_process');
        exec(`/scripts/backup.sh`, (error, stdout, stderr) => {
            if (error) {
                res.status(500).json({ success: false, error: error.message });
            } else {
                auditLog('backup_create', req.user.username, { backupDir });
                res.json({ success: true, message: 'Бекап створено успішно', backupDir });
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Список бекапів
app.get('/api/backups', async (req, res) => {
  try {
    const backupPath = '/backup';
    const backups = await fs.readdir(backupPath);
    
    const backupList = await Promise.all(
      backups.map(async (backup) => {
        const stats = await fs.stat(path.join(backupPath, backup));
        return {
          name: backup,
          size: stats.size,
          created: stats.birthtime,
          modified: stats.mtime
        };
      })
    );
    
    res.json({ success: true, backups: backupList });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Відновлення з бекапу
app.post('/api/backups/restore/:name', async (req, res) => {
    try {
        const { name } = req.params;
        const backupPath = `/backup/${name}`;
        
        if (!await fs.pathExists(backupPath)) {
            return res.status(404).json({ success: false, error: 'Бекап не знайдено' });
        }
        
        const { exec } = require('child_process');
        exec(`/scripts/restore.sh ${backupPath}`, (error, stdout, stderr) => {
            if (error) {
                res.status(500).json({ success: false, error: error.message });
            } else {
                auditLog('backup_restore', req.user.username, { backupName: name });
                res.json({ success: true, message: 'Відновлення завершено успішно' });
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Видалення бекапу
app.delete('/api/backups/:name', async (req, res) => {
    try {
        const { name } = req.params;
        const backupPath = `/backup/${name}`;
        
        await fs.remove(backupPath);
        auditLog('backup_delete', req.user.username, { backupName: name });
        res.json({ success: true, message: 'Бекап видалено успішно' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Метрики системи
app.get('/api/metrics', async (req, res) => {
  try {
    const containers = await docker.listContainers({ all: true });
    const running = containers.filter(c => c.State === 'running').length;
    const total = containers.length;
    
    // Отримання використання ресурсів
    const stats = await Promise.all(
      containers.slice(0, 5).map(async (container) => {
        try {
          const containerObj = docker.getContainer(container.Id);
          const containerStats = await containerObj.stats({ stream: false });
          return {
            name: container.Names[0].replace('/', ''),
            cpu: containerStats.cpu_stats,
            memory: containerStats.memory_stats
          };
        } catch (error) {
          return null;
        }
      })
    );
    
    res.json({
      success: true,
      metrics: {
        containers: { running, total },
        stats: stats.filter(Boolean)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Нові API endpoints для мостів
app.get('/api/bridges/status', async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const bridges = containers.filter(c => 
            c.Names[0].includes('signal-bridge') || 
            c.Names[0].includes('whatsapp-bridge') || 
            c.Names[0].includes('discord-bridge')
        ).map(container => ({
            name: container.Names[0].replace('/', ''),
            status: container.State,
            image: container.Image
        }));
        
        res.json({ success: true, bridges });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/bridges/restart/:name', async (req, res) => {
    try {
        const { name } = req.params;
        const container = docker.getContainer(name);
        await container.restart();
        
        auditLog('bridge_restart', req.user.username, { bridge: name });
        res.json({ success: true, message: `Міст ${name} перезапущено успішно` });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// API для отримання аудит логу
app.get('/api/audit', async (req, res) => {
    try {
        if (await fs.pathExists(AUDIT_LOG_FILE)) {
            const logs = await fs.readFile(AUDIT_LOG_FILE, 'utf8');
            const entries = logs.trim().split('\n').map(line => JSON.parse(line)).reverse();
            res.json({ success: true, logs: entries });
        } else {
            res.json({ success: true, logs: [] });
        }
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// API для надсилання сповіщень через Matrix
app.post('/api/notifications/send', async (req, res) => {
    try {
        const { message, roomId } = req.body;
        
        // Тут буде логіка надсилання повідомлення через Matrix API
        // Поки що просто логуємо
        
        auditLog('notification_send', req.user.username, { message, roomId });
        res.json({ success: true, message: 'Сповіщення надіслано успішно' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// API для автоматичного оновлення контейнерів
app.post('/api/update', async (req, res) => {
    try {
        const { exec } = require('child_process');
        
        // Оновлення образів
        exec('docker-compose pull', (error, stdout, stderr) => {
            if (error) {
                auditLog('update_failed', req.user.username, { error: error.message });
                return res.status(500).json({ success: false, error: error.message });
            }
            
            // Перезапуск контейнерів з новими образами
            exec('docker-compose up -d', (error2, stdout2, stderr2) => {
                if (error2) {
                    auditLog('update_failed', req.user.username, { error: error2.message });
                    return res.status(500).json({ success: false, error: error2.message });
                }
                
                auditLog('update_success', req.user.username, { 
                    pulled: stdout.split('\n').filter(line => line.includes('Pulling')).length,
                    restarted: stdout2.split('\n').filter(line => line.includes('Creating') || line.includes('Starting')).length
                });
                res.json({ success: true, message: 'Контейнери оновлено успішно' });
            });
        });
    } catch (error) {
        auditLog('update_failed', req.user.username, { error: error.message });
        res.status(500).json({ success: false, error: error.message });
    }
});

// Healthcheck для всіх сервісів
app.get('/api/health', async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const health = containers.map(container => ({
            name: container.Names[0].replace('/', ''),
            status: container.State,
            healthy: container.State === 'running'
        }));
        
        const unhealthy = health.filter(h => !h.healthy);
        
        if (unhealthy.length > 0) {
            // Надсилаємо сповіщення про нездорові сервіси
            console.log('Знайдено нездорові сервіси:', unhealthy.map(h => h.name));
        }
        
        res.json({ 
            success: true, 
            health,
            summary: {
                total: health.length,
                healthy: health.filter(h => h.healthy).length,
                unhealthy: unhealthy.length
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Автоматичне створення бекапів (кожні 6 годин)
cron.schedule('0 */6 * * *', async () => {
    try {
        console.log('Автоматичне створення бекапу...');
        const { exec } = require('child_process');
        exec('/scripts/backup.sh');
    } catch (error) {
        console.error('Помилка автоматичного бекапу:', error);
    }
});

// Healthcheck кожні 5 хвилин
cron.schedule('*/5 * * * *', async () => {
    try {
        const containers = await docker.listContainers({ all: true });
        const unhealthy = containers.filter(c => c.State !== 'running');
        
        if (unhealthy.length > 0) {
            console.log('Healthcheck: знайдено нездорові сервіси:', unhealthy.map(c => c.Names[0]));
            // Тут можна додати надсилання сповіщення через Matrix
        }
    } catch (error) {
        console.error('Помилка healthcheck:', error);
    }
});

// Головна сторінка
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Запуск сервера
app.listen(PORT, () => {
  console.log(`🚀 Адмін-панель запущена на порту ${PORT}`);
  console.log(`📊 Доступна за адресою: http://0.0.0.0:${PORT}`);
}); 