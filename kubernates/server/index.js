const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const os = require('os');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// Persistent Volume directory (/app/data mounted from 08-pvc.yaml)
const DATA_DIR = '/app/data';
const USERS_FILE = path.join(DATA_DIR, 'users.json');

// Helper: Load users from Persistent Volume + merge with Kubernetes Secret (03-secret.yaml)
function getUsers() {
  // 1. Default Admin & User injected from Kubernetes 03-secret.yaml
  const secretUsers = [
    {
      username: process.env.ADMIN_USERNAME || 'admin@northpointliving.com',
      password: process.env.ADMIN_PASSWORD || 'Admin@Northpoint2026!',
      role: 'admin',
      source: '03-secret.yaml (Kubernetes Secret)'
    },
    {
      username: process.env.USER_USERNAME || 'staff@northpointliving.com',
      password: process.env.USER_PASSWORD || 'Staff@Northpoint2026!',
      role: 'user',
      source: '03-secret.yaml (Kubernetes Secret)'
    }
  ];

  // 2. Custom users saved on Persistent Volume (/app/data/users.json)
  let volumeUsers = [];
  try {
    if (fs.existsSync(USERS_FILE)) {
      volumeUsers = JSON.parse(fs.readFileSync(USERS_FILE, 'utf-8'));
    }
  } catch (err) {
    console.error('Error reading users file:', err.message);
  }

  return [...secretUsers, ...volumeUsers];
}

let totalRequests = 0;
app.use((req, res, next) => {
  totalRequests++;
  next();
});

// Kubernetes Startup, Readiness & Liveness Probe Endpoint (JSON format for K8s)
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'Northpoint Living Storefront',
    pod_name: os.hostname(),
    environment: process.env.APP_ENV || 'prod',
    db_host: process.env.DB_HOST || '10.0.0.5',
    media_bucket: process.env.MEDIA_BUCKET || 'northpoint-media-prod',
    admin_configured: Boolean(process.env.ADMIN_PASSWORD),
    timestamp: new Date().toISOString()
  });
});

// Prometheus Monitoring Endpoint (/metrics — Prometheus Text Format!)
app.get('/metrics', (req, res) => {
  const mem = process.memoryUsage();
  const usersCount = getUsers().length;
  res.set('Content-Type', 'text/plain; version=0.0.4');
  res.send(
`# HELP northpoint_storefront_up Whether the Northpoint Living Storefront Pod is healthy (1 = up)
# TYPE northpoint_storefront_up gauge
northpoint_storefront_up{pod="${os.hostname()}",env="${process.env.APP_ENV || 'prod'}"} 1
# HELP northpoint_http_requests_total Total HTTP requests handled by this Pod
# TYPE northpoint_http_requests_total counter
northpoint_http_requests_total{pod="${os.hostname()}"} ${totalRequests}
# HELP northpoint_registered_users_total Total users configured (Secret + PVC Volume)
# TYPE northpoint_registered_users_total gauge
northpoint_registered_users_total{pod="${os.hostname()}"} ${usersCount}
# HELP northpoint_memory_rss_bytes Resident memory usage in bytes
# TYPE northpoint_memory_rss_bytes gauge
northpoint_memory_rss_bytes{pod="${os.hostname()}"} ${mem.rss}
`
  );
});

// Login Endpoint (Checks 03-secret.yaml credentials + Persistent Volume users)
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  const users = getUsers();
  const matched = users.find(u => u.username === username && u.password === password);

  if (!matched) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  res.json({
    message: `Welcome ${matched.username}!`,
    username: matched.username,
    role: matched.role,
    source: matched.source,
    pod_name: os.hostname()
  });
});

// Admin Endpoint: List all users (without exposing plain passwords)
app.get('/api/users', (req, res) => {
  const users = getUsers().map(u => ({
    username: u.username,
    role: u.role,
    source: u.source
  }));
  res.json(users);
});

// Admin Endpoint: Create a new User/Admin saved permanently on 08-pvc.yaml (/app/data/users.json)
app.post('/api/users', (req, res) => {
  const { adminPassword, newUsername, newPassword, newRole } = req.body;
  const expectedAdminPass = process.env.ADMIN_PASSWORD || 'Admin@Northpoint2026!';

  if (adminPassword !== expectedAdminPass) {
    return res.status(403).json({ error: 'Unauthorized: Invalid Admin Password from 03-secret.yaml' });
  }

  let volumeUsers = [];
  if (fs.existsSync(USERS_FILE)) {
    volumeUsers = JSON.parse(fs.readFileSync(USERS_FILE, 'utf-8'));
  }

  volumeUsers.push({
    username: newUsername,
    password: newPassword,
    role: newRole || 'user',
    source: '08-pvc.yaml (/app/data/users.json)'
  });

  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  fs.writeFileSync(USERS_FILE, JSON.stringify(volumeUsers, null, 2), 'utf-8');

  res.json({ message: `Created ${newRole || 'user'} ${newUsername} on Persistent Volume!` });
});

// Sample E-commerce Products Endpoint
app.get('/api/products', (req, res) => {
  res.json([
    { id: 1, name: 'Nordic Oak Dining Table', price_hkd: 4800, stock: 18 },
    { id: 2, name: 'Victoria Peak Linen Sofa', price_hkd: 7250, stock: 9 },
    { id: 3, name: 'Ceramic Artisan Tea Set', price_hkd: 680, stock: 45 }
  ]);
});

// Serve compiled frontend from client/dist
const clientDist = path.join(__dirname, '../client/dist');
app.use(express.static(clientDist));

app.get('*', (req, res) => {
  res.sendFile(path.join(clientDist, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Northpoint Living Storefront listening on port ${PORT} (Pod: ${os.hostname()})`);
});
