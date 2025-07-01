// Глобальні змінні
let currentService = '';
let metricsChart = null;
let updateInterval = null;
let authToken = localStorage.getItem('authToken');
let currentUser = localStorage.getItem('currentUser');

// Головний JavaScript файл для адмін-панелі

class AdminPanel {
    constructor() {
        this.currentTime = new Date();
        this.chart = null;
        this.authToken = localStorage.getItem('authToken');
        this.currentUser = localStorage.getItem('currentUser');
        this.init();
    }

    init() {
        // Перевірка автентифікації
        if (!this.authToken || !this.currentUser) {
            this.showAuthPanel();
            return;
        }
        
        this.showMainPanel();
        this.updateTime();
        this.loadDashboard();
        this.setupEventListeners();
        this.startAutoRefresh();
        this.loadTheme();
    }

    showAuthPanel() {
        document.getElementById('auth-container').style.display = 'flex';
        document.getElementById('main-container').style.display = 'none';
    }

    showMainPanel() {
        document.getElementById('auth-container').style.display = 'none';
        document.getElementById('main-container').style.display = 'block';
        document.getElementById('current-user').textContent = this.currentUser;
    }

    updateTime() {
        const timeElement = document.getElementById('current-time');
        if (timeElement) {
            timeElement.textContent = new Date().toLocaleString('uk-UA');
        }
    }

    setupEventListeners() {
        // Оновлення часу кожну секунду
        setInterval(() => this.updateTime(), 1000);

        // Обробка навігації
        document.querySelectorAll('[data-bs-toggle="tab"]').forEach(tab => {
            tab.addEventListener('click', (e) => {
                const target = e.target.getAttribute('href');
                this.loadTabContent(target);
            });
        });

        // Обробка форми автентифікації
        document.getElementById('login-form').addEventListener('submit', (e) => this.handleLogin(e));
    }

    async handleLogin(event) {
        event.preventDefault();
        
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        
        try {
            const response = await fetch('/api/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ username, password })
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.authToken = data.token;
                this.currentUser = data.username;
                
                localStorage.setItem('authToken', this.authToken);
                localStorage.setItem('currentUser', this.currentUser);
                
                this.showMainPanel();
                this.loadDashboard();
                this.showNotification('Успішна автентифікація!', 'success');
            } else {
                this.showNotification(data.error || 'Помилка автентифікації', 'error');
            }
        } catch (error) {
            this.showNotification('Помилка з\'єднання', 'error');
        }
    }

    logout() {
        localStorage.removeItem('authToken');
        localStorage.removeItem('currentUser');
        this.authToken = null;
        this.currentUser = null;
        this.showAuthPanel();
    }

    // Функція для API запитів з авторизацією
    async apiRequest(endpoint, options = {}) {
        const defaultOptions = {
            headers: {
                'Authorization': `Bearer ${this.authToken}`,
                'Content-Type': 'application/json'
            }
        };
        
        const finalOptions = { ...defaultOptions, ...options };
        
        const response = await fetch(`/api/${endpoint}`, finalOptions);
        
        if (response.status === 401) {
            this.logout();
            return null;
        }
        
        return response.json();
    }

    async loadTabContent(tabId) {
        switch (tabId) {
            case '#dashboard':
                await this.loadDashboard();
                break;
            case '#services':
                await this.loadServices();
                break;
            case '#users':
                await this.loadUsers();
                break;
            case '#backups':
                await this.loadBackups();
                break;
            case '#logs':
                await this.loadServiceList();
                break;
            case '#audit':
                await this.loadAuditLog();
                break;
            case '#monitoring':
                await this.loadHealthcheck();
                break;
        }
    }

    async loadDashboard() {
        try {
            const [statusResponse, healthResponse] = await Promise.all([
                this.apiRequest('status'),
                this.apiRequest('health')
            ]);

            if (statusResponse && statusResponse.success) {
                this.updateDashboardMetrics(statusResponse.services, healthResponse);
            }
        } catch (error) {
            this.showNotification('Помилка завантаження дашборду', 'error');
        }
    }

    updateDashboardMetrics(services, health) {
        const running = services.filter(s => s.status === 'running').length;
        const total = services.length;

        document.getElementById('running-services').textContent = running;
        document.getElementById('total-services').textContent = total;
        document.getElementById('system-status').textContent = running === total ? 'OK' : 'WARNING';

        if (health && health.success) {
            document.getElementById('total-users').textContent = health.summary?.total || 0;
        }

        this.updateMetricsChart();
    }

    updateMetricsChart(metrics) {
        const ctx = document.getElementById('metricsChart');
        if (!ctx) return;

        if (this.chart) {
            this.chart.destroy();
        }

        this.chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: ['CPU', 'Memory', 'Network'],
                datasets: [{
                    label: 'Використання ресурсів',
                    data: [65, 45, 30],
                    borderColor: 'rgb(75, 192, 192)',
                    backgroundColor: 'rgba(75, 192, 192, 0.2)',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100
                    }
                }
            }
        });
    }

    async loadServices() {
        try {
            const data = await this.apiRequest('status');

            if (data && data.success) {
                this.renderServicesTable(data.services);
            }
        } catch (error) {
            this.showNotification('Помилка завантаження сервісів', 'error');
        }
    }

    renderServicesTable(services) {
        const tbody = document.getElementById('services-table');
        if (!tbody) return;

        tbody.innerHTML = services.map(service => `
            <tr>
                <td>
                    <strong>${service.name}</strong>
                    <br><small class="text-muted">${service.image}</small>
                </td>
                <td>
                    <span class="badge status-badge status-${service.status}">
                        ${service.status}
                    </span>
                </td>
                <td>${service.image}</td>
                <td>${this.formatPorts(service.ports)}</td>
                <td class="service-actions">
                    ${this.getServiceActions(service)}
                </td>
            </tr>
        `).join('');
    }

    formatPorts(ports) {
        if (!ports || ports.length === 0) return '-';
        return ports.map(port => `${port.PublicPort}:${port.PrivatePort}`).join(', ');
    }

    getServiceActions(service) {
        const actions = [];
        
        if (service.status === 'running') {
            actions.push(`<button class="btn btn-warning btn-sm" onclick="controlService('stop', '${service.name}')">
                <i class="fas fa-stop"></i>
            </button>`);
            actions.push(`<button class="btn btn-info btn-sm" onclick="controlService('restart', '${service.name}')">
                <i class="fas fa-redo"></i>
            </button>`);
        } else {
            actions.push(`<button class="btn btn-success btn-sm" onclick="controlService('start', '${service.name}')">
                <i class="fas fa-play"></i>
            </button>`);
        }

        return actions.join('');
    }

    async loadUsers() {
        try {
            const data = await this.apiRequest('users');

            if (data && data.success) {
                this.renderUsersTable(data.users);
            }
        } catch (error) {
            this.showNotification('Помилка завантаження користувачів', 'error');
        }
    }

    renderUsersTable(users) {
        const tbody = document.getElementById('users-table');
        if (!tbody) return;

        if (users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center">Користувачів не знайдено</td></tr>';
            return;
        }

        tbody.innerHTML = users.map(user => `
            <tr>
                <td>${user.username}</td>
                <td>${new Date(user.created_at).toLocaleDateString('uk-UA')}</td>
                <td><span class="badge bg-success">Активний</span></td>
                <td>
                    <button class="btn btn-danger btn-sm" onclick="deleteUser('${user.username}')">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async loadBackups() {
        try {
            const data = await this.apiRequest('backups');

            if (data && data.success) {
                this.renderBackupsTable(data.backups);
                document.getElementById('backup-count').textContent = data.backups.length;
            }
        } catch (error) {
            this.showNotification('Помилка завантаження бекапів', 'error');
        }
    }

    renderBackupsTable(backups) {
        const tbody = document.getElementById('backups-table');
        if (!tbody) return;

        if (backups.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center">Бекапів не знайдено</td></tr>';
            return;
        }

        tbody.innerHTML = backups.map(backup => `
            <tr>
                <td>${backup.name}</td>
                <td>${this.formatBytes(backup.size)}</td>
                <td>${new Date(backup.created).toLocaleString('uk-UA')}</td>
                <td>
                    <button class="btn btn-success btn-sm me-1" onclick="restoreBackup('${backup.name}')">
                        <i class="fas fa-undo"></i>
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="deleteBackup('${backup.name}')">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async loadServiceList() {
        try {
            const data = await this.apiRequest('status');

            if (data && data.success) {
                const select = document.getElementById('service-select');
                select.innerHTML = '<option value="">Виберіть сервіс...</option>' +
                    data.services.map(service => 
                        `<option value="${service.name}">${service.name}</option>`
                    ).join('');
            }
        } catch (error) {
            this.showNotification('Помилка завантаження списку сервісів', 'error');
        }
    }

    formatBytes(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    showNotification(message, type = 'info') {
        const toast = document.getElementById('notification');
        const messageEl = document.getElementById('notification-message');
        
        messageEl.textContent = message;
        
        // Додавання класу для типу сповіщення
        toast.className = `toast ${type === 'error' ? 'bg-danger text-white' : ''}`;
        
        const bsToast = new bootstrap.Toast(toast);
        bsToast.show();
    }

    startAutoRefresh() {
        // Оновлення дашборду кожні 30 секунд
        setInterval(() => {
            const activeTab = document.querySelector('.tab-pane.active');
            if (activeTab && activeTab.id === 'dashboard') {
                this.loadDashboard();
            }
        }, 30000);
    }

    async loadAuditLog() {
        const table = document.getElementById('audit-log-table');
        if (!table) return;
        table.innerHTML = '<tr><td colspan="5">Завантаження...</td></tr>';
        try {
            const response = await this.apiRequest('audit');
            if (response && response.success) {
                const logs = response.logs;
                if (logs.length === 0) {
                    table.innerHTML = '<tr><td colspan="5">Подій не знайдено</td></tr>';
                    return;
                }
                table.innerHTML = logs.map(log => `
                    <tr>
                        <td>${new Date(log.timestamp).toLocaleString('uk-UA')}</td>
                        <td>${log.user}</td>
                        <td>${log.action}</td>
                        <td>${JSON.stringify(log.details)}</td>
                        <td>${log.result || ''}</td>
                    </tr>
                `).join('');
            } else {
                table.innerHTML = '<tr><td colspan="5">Помилка завантаження</td></tr>';
            }
        } catch (e) {
            table.innerHTML = '<tr><td colspan="5">Помилка з\'єднання</td></tr>';
        }
    }

    async loadHealthcheck() {
        const container = document.getElementById('healthcheck-container');
        if (!container) return;
        container.innerHTML = '<p>Завантаження...</p>';
        try {
            const response = await this.apiRequest('health');
            if (response && response.success) {
                const { health, summary } = response;
                container.innerHTML = `
                    <div class="row mb-3">
                        <div class="col-md-3">
                            <div class="card bg-success text-white">
                                <div class="card-body text-center">
                                    <h4>${summary.healthy}</h4>
                                    <p class="mb-0">Здорові</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="card bg-danger text-white">
                                <div class="card-body text-center">
                                    <h4>${summary.unhealthy}</h4>
                                    <p class="mb-0">Нездорові</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="card bg-info text-white">
                                <div class="card-body text-center">
                                    <h4>${summary.total}</h4>
                                    <p class="mb-0">Всього</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <button class="btn btn-primary w-100" onclick="adminPanel.loadHealthcheck()">
                                <i class="fas fa-sync-alt me-1"></i>Оновити
                            </button>
                        </div>
                    </div>
                    <div class="row mb-3">
                        <div class="col-12">
                            <button class="btn btn-warning" onclick="adminPanel.updateContainers()">
                                <i class="fas fa-download me-1"></i>Оновити контейнери
                            </button>
                        </div>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-striped">
                            <thead>
                                <tr>
                                    <th>Сервіс</th>
                                    <th>Статус</th>
                                    <th>Стан</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${health.map(service => `
                                    <tr>
                                        <td>${service.name}</td>
                                        <td>
                                            <span class="badge ${service.healthy ? 'bg-success' : 'bg-danger'}">
                                                ${service.healthy ? 'Здоров' : 'Нездоров'}
                                            </span>
                                        </td>
                                        <td>${service.status}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                `;
            } else {
                container.innerHTML = '<p class="text-danger">Помилка завантаження healthcheck</p>';
            }
        } catch (e) {
            container.innerHTML = '<p class="text-danger">Помилка з\'єднання</p>';
        }
    }

    async updateContainers() {
        if (!confirm('Ви впевнені, що хочете оновити всі контейнери? Це може зайняти кілька хвилин.')) {
            return;
        }
        
        try {
            const response = await this.apiRequest('update', {
                method: 'POST'
            });
            
            if (response && response.success) {
                this.showNotification('Контейнери оновлено успішно!', 'success');
                setTimeout(() => this.loadHealthcheck(), 5000);
            } else {
                this.showNotification(response?.error || 'Помилка оновлення', 'error');
            }
        } catch (error) {
            this.showNotification('Помилка з\'єднання', 'error');
        }
    }

    loadTheme() {
        const theme = localStorage.getItem('theme') || 'light';
        document.documentElement.setAttribute('data-bs-theme', theme);
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.innerHTML = theme === 'dark' ? 
                '<i class="fas fa-sun me-1"></i>Світла' : 
                '<i class="fas fa-moon me-1"></i>Темна';
        }
    }

    toggleTheme() {
        const currentTheme = document.documentElement.getAttribute('data-bs-theme') || 'light';
        const newTheme = currentTheme === 'light' ? 'dark' : 'light';
        document.documentElement.setAttribute('data-bs-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.innerHTML = newTheme === 'dark' ? 
                '<i class="fas fa-sun me-1"></i>Світла' : 
                '<i class="fas fa-moon me-1"></i>Темна';
        }
    }
}

// Глобальні функції для кнопок

async function controlService(action, name) {
    try {
        const data = await adminPanel.apiRequest(`service/${action}/${name}`, {
            method: 'POST'
        });

        if (data && data.success) {
            adminPanel.showNotification(data.message, 'success');
            adminPanel.loadServices();
        } else {
            adminPanel.showNotification(data?.error || 'Помилка керування сервісом', 'error');
        }
    } catch (error) {
        adminPanel.showNotification('Помилка керування сервісом', 'error');
    }
}

async function createUser() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const displayName = document.getElementById('displayName').value;

    if (!username || !password) {
        adminPanel.showNotification('Заповніть обов\'язкові поля', 'error');
        return;
    }

    try {
        const data = await adminPanel.apiRequest('users/create', {
            method: 'POST',
            body: JSON.stringify({ username, password, displayName })
        });

        if (data && data.success) {
            adminPanel.showNotification('Користувача створено успішно', 'success');
            bootstrap.Modal.getInstance(document.getElementById('createUserModal')).hide();
            document.getElementById('createUserForm').reset();
            adminPanel.loadUsers();
        } else {
            adminPanel.showNotification(data?.error || 'Помилка створення користувача', 'error');
        }
    } catch (error) {
        adminPanel.showNotification('Помилка створення користувача', 'error');
    }
}

async function createBackup() {
    try {
        const data = await adminPanel.apiRequest('backups/create', {
            method: 'POST'
        });

        if (data && data.success) {
            adminPanel.showNotification('Бекап створено успішно', 'success');
            adminPanel.loadBackups();
        } else {
            adminPanel.showNotification(data?.error || 'Помилка створення бекапу', 'error');
        }
    } catch (error) {
        adminPanel.showNotification('Помилка створення бекапу', 'error');
    }
}

async function restoreBackup(name) {
    if (!confirm(`Відновити бекап "${name}"? Це може перезаписати поточні дані.`)) {
        return;
    }

    try {
        const response = await fetch(`/api/backups/restore/${name}`, {
            method: 'POST'
        });
        const data = await response.json();

        if (data.success) {
            adminPanel.showNotification('Відновлення завершено успішно', 'success');
        } else {
            adminPanel.showNotification(data.error, 'error');
        }
    } catch (error) {
        adminPanel.showNotification('Помилка відновлення', 'error');
    }
}

async function deleteBackup(name) {
    if (!confirm(`Видалити бекап "${name}"?`)) {
        return;
    }

    try {
        const response = await fetch(`/api/backups/${name}`, {
            method: 'DELETE'
        });
        const data = await response.json();

        if (data.success) {
            adminPanel.showNotification('Бекап видалено успішно', 'success');
            adminPanel.loadBackups();
        } else {
            adminPanel.showNotification(data.error, 'error');
        }
    } catch (error) {
        adminPanel.showNotification('Помилка видалення бекапу', 'error');
    }
}

async function loadLogs() {
    const service = document.getElementById('service-select').value;
    const lines = document.getElementById('log-lines').value;

    if (!service) {
        adminPanel.showNotification('Виберіть сервіс', 'error');
        return;
    }

    try {
        const response = await fetch(`/api/logs/${service}?lines=${lines}`);
        const data = await response.json();

        if (data.success) {
            document.getElementById('logs-content').textContent = data.logs;
        } else {
            adminPanel.showNotification(data.error, 'error');
        }
    } catch (error) {
        adminPanel.showNotification('Помилка завантаження логів', 'error');
    }
}

// Функції для кнопок оновлення
function refreshServices() {
    adminPanel.loadServices();
}

function refreshBackups() {
    adminPanel.loadBackups();
}

// Ініціалізація при завантаженні сторінки
let adminPanel;
document.addEventListener('DOMContentLoaded', () => {
    adminPanel = new AdminPanel();
}); 