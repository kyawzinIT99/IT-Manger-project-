const fs = require('fs');
const path = require('path');

const distDir = path.join(__dirname, 'dist');
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true });
}

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Northpoint Living — Hong Kong Homeware Storefront</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; background: #f8fafc; color: #0f172a; }
    header { background: #1e3a8a; color: white; padding: 20px 32px; display: flex; justify-content: space-between; align-items: center; }
    .badge { background: #10b981; color: white; padding: 6px 12px; border-radius: 999px; font-size: 13px; font-weight: 600; }
    .container { max-width: 980px; margin: 28px auto; padding: 0 20px; }
    .card { background: white; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
    .price { color: #2563eb; font-weight: 700; font-size: 18px; }
    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 13px; }
    input, select { width: 100%; padding: 8px 10px; margin: 6px 0 12px; border: 1px solid #cbd5e1; border-radius: 6px; box-sizing: border-box; font-size: 14px; }
    button { background: #2563eb; color: white; border: none; padding: 9px 16px; border-radius: 6px; font-weight: 600; cursor: pointer; font-size: 14px; }
    button:hover { background: #1d4ed8; }
    .btn-quick { background: #475569; font-size: 12px; padding: 5px 10px; margin-right: 6px; margin-bottom: 8px; }
    .status-ok { background: #dcfce7; color: #166534; padding: 10px 14px; border-radius: 8px; margin-top: 10px; font-weight: 600; }
    .status-err { background: #fee2e2; color: #991b1b; padding: 10px 14px; border-radius: 8px; margin-top: 10px; font-weight: 600; }
    table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 14px; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #e2e8f0; }
    th { background: #f1f5f9; }
  </style>
</head>
<body>
  <header>
    <div>
      <h1 style="margin:0;font-size:22px;">🏠 Northpoint Living — Hong Kong</h1>
      <p style="margin:4px 0 0;opacity:0.85;font-size:14px;">Docker + Kubernetes Storefront (03-secret.yaml Auth + 08-pvc.yaml Storage)</p>
    </div>
    <span class="badge" id="user-badge">🔒 Not Logged In</span>
  </header>

  <div class="container">
    <div class="grid">
      <!-- LOGIN BOX -->
      <div class="card">
        <h2 style="margin-top:0;">🔑 User & Admin Login</h2>
        <p style="font-size:13px;color:#475569;margin-top:0;">Quick-fill credentials from <code>03-secret.yaml</code>:</p>
        <button class="btn-quick" onclick="fillLogin('admin@northpointliving.com', 'Admin@Northpoint2026!')">Fill Admin</button>
        <button class="btn-quick" onclick="fillLogin('staff@northpointliving.com', 'Staff@Northpoint2026!')">Fill Staff User</button>

        <label style="font-size:13px;font-weight:600;">Username / Email</label>
        <input id="login-user" type="text" placeholder="admin@northpointliving.com" />

        <label style="font-size:13px;font-weight:600;">Password</label>
        <input id="login-pass" type="password" placeholder="Admin@Northpoint2026!" />

        <button onclick="doLogin()">Log In to Storefront</button>
        <div id="login-result"></div>
      </div>

      <!-- ADMIN CONTROL PANEL (CREATE USERS ON PERSISTENT VOLUME) -->
      <div class="card">
        <h2 style="margin-top:0;">🛡️ Admin Control Panel (Create User)</h2>
        <p style="font-size:13px;color:#475569;margin-top:0;">Saves new users permanently on <code>08-pvc.yaml</code> (<code>/app/data/users.json</code>):</p>

        <label style="font-size:13px;font-weight:600;">Admin Password (from 03-secret.yaml)</label>
        <input id="admin-pass" type="password" value="Admin@Northpoint2026!" />

        <label style="font-size:13px;font-weight:600;">New Username / Email</label>
        <input id="new-user" type="text" placeholder="customer1@northpointliving.com" />

        <label style="font-size:13px;font-weight:600;">New Password</label>
        <input id="new-pass" type="text" placeholder="Customer@123" />

        <label style="font-size:13px;font-weight:600;">Role</label>
        <select id="new-role">
          <option value="user">Customer / Staff (user)</option>
          <option value="admin">Administrator (admin)</option>
        </select>

        <button onclick="createUser()">+ Create User on Persistent Volume</button>
        <div id="create-result"></div>
      </div>
    </div>

    <!-- REGISTERED USERS TABLE -->
    <div class="card">
      <div style="display:flex;justify-content:space-between;align-items:center;">
        <h2 style="margin:0;">👥 Active Users (03-secret.yaml + 08-pvc.yaml Volume)</h2>
        <button class="btn-quick" onclick="loadUsers()">🔄 Refresh List</button>
      </div>
      <table>
        <thead>
          <tr>
            <th>Username</th>
            <th>Role</th>
            <th>Where It Is Stored</th>
          </tr>
        </thead>
        <tbody id="users-table">
          <tr><td colspan="3">Loading users...</td></tr>
        </tbody>
      </table>
    </div>

    <!-- POD HEALTH -->
    <div class="card">
      <h2 style="margin-top:0;">🚀 Live Kubernetes Pod Status</h2>
      <p>Health API: <a href="/api/health"><code>/api/health</code></a> | Users API: <a href="/api/users"><code>/api/users</code></a> | Products API: <a href="/api/products"><code>/api/products</code></a></p>
      <pre id="health-box" style="background:#0f172a;color:#38bdf8;padding:14px;border-radius:8px;overflow-x:auto;">Loading pod health...</pre>
    </div>
  </div>

  <script>
    function fillLogin(u, p) {
      document.getElementById('login-user').value = u;
      document.getElementById('login-pass').value = p;
    }

    function doLogin() {
      const username = document.getElementById('login-user').value;
      const password = document.getElementById('login-pass').value;
      const box = document.getElementById('login-result');
      fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      })
      .then(async r => ({ ok: r.ok, data: await r.json() }))
      .then(({ ok, data }) => {
        if (ok) {
          box.className = 'status-ok';
          box.textContent = '✅ ' + data.message + ' | Role: ' + data.role.toUpperCase() + ' | Answered by Pod: ' + data.pod_name;
          document.getElementById('user-badge').textContent = '👤 ' + data.username + ' (' + data.role.toUpperCase() + ')';
        } else {
          box.className = 'status-err';
          box.textContent = '❌ ' + (data.error || 'Login failed');
        }
      });
    }

    function createUser() {
      const adminPassword = document.getElementById('admin-pass').value;
      const newUsername = document.getElementById('new-user').value;
      const newPassword = document.getElementById('new-pass').value;
      const newRole = document.getElementById('new-role').value;
      const box = document.getElementById('create-result');

      fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ adminPassword, newUsername, newPassword, newRole })
      })
      .then(async r => ({ ok: r.ok, data: await r.json() }))
      .then(({ ok, data }) => {
        if (ok) {
          box.className = 'status-ok';
          box.textContent = '✅ ' + data.message;
          loadUsers();
        } else {
          box.className = 'status-err';
          box.textContent = '❌ ' + (data.error || 'Failed to create user');
        }
      });
    }

    function loadUsers() {
      fetch('/api/users')
        .then(r => r.json())
        .then(users => {
          const tbody = document.getElementById('users-table');
          tbody.innerHTML = users.map(u =>
            '<tr><td><strong>' + u.username + '</strong></td><td><code>' + u.role + '</code></td><td>' + u.source + '</td></tr>'
          ).join('');
        });
    }

    fetch('/api/health')
      .then(r => r.json())
      .then(data => {
        document.getElementById('health-box').textContent = JSON.stringify(data, null, 2);
      });

    loadUsers();
  </script>
</body>
</html>`;

fs.writeFileSync(path.join(distDir, 'index.html'), html, 'utf-8');
console.log('✅ Built Northpoint Living frontend with Login & Admin Panel to client/dist/index.html');
