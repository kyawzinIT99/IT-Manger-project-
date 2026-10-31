# 🤖 Northpoint Living — Ansible + Docker + `tmux` Hands-On Lab

Everything in this lab is self-contained inside `/Users/berry/Antigravity/IT Manager project /Ansible/`. All logs, backups, and test reports are automatically saved in `./test-outputs/` inside this exact same folder.

---

## 🏗️ 1. Lab Architecture (MacBook Workstation → 3 Docker Servers)

```text
💻 YOUR MACBOOK (Local Workstation / Ansible Control Node + tmux)
 │
 ├── Reads: ansible.cfg + inventory.ini
 ├── Saves all logs & test files in: ./test-outputs/
 │
 ├──► SSH Port 2221 ──► 🐳 server1 (northpoint-srv-01 | 172.28.0.11) [Web Storefront 1]
 ├──► SSH Port 2222 ──► 🐳 server2 (northpoint-srv-02 | 172.28.0.12) [Web Storefront 2]
 └──► SSH Port 2223 ──► 🐳 server3 (northpoint-srv-03 | 172.28.0.13) [Legacy DB & Backup]
```

* **SSH Username (all 3 servers):** `ansible`
* **SSH Password (all 3 servers):** `northpoint`

---

## 📂 2. Files in This Folder

| File | Purpose |
| :--- | :--- |
| [`Dockerfile.node`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/Dockerfile.node) | Builds an Ubuntu 22.04 server image with OpenSSH Server (`port 22`), Python3, and passwordless `sudo`. |
| [`docker-compose.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/docker-compose.yml) | Starts `server1` (`2221`), `server2` (`2222`), and `server3` (`2223`) on subnet `172.28.0.0/16` and maps `./test-outputs/` to `/var/northpoint_backups`. |
| [`ansible.cfg`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/ansible.cfg) | Configures Ansible to use `./inventory.ini` and write execution logs to `./test-outputs/ansible-execution.log`. |
| [`inventory.ini`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/inventory.ini) | Defines `[webservers]` (`server1`, `server2`) and `[dbservers]` (`server3`). |
| [`01-setup-tmux-and-tools.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/01-setup-tmux-and-tools.yml) | Playbook 1: Installs `tmux`, `htop`, `vim`, `tree` on all 3 servers and configures a custom `tmux` status bar. |
| [`02-network-and-backup-test.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/02-network-and-backup-test.yml) | Playbook 2: Runs a CCNA network/routing audit (`ip route`, `ss -tlnp`, `ping`) and creates `.tar.gz` + `.sha256` backups in `./test-outputs/`. |
| [`03-git-connect-and-deploy.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/03-git-connect-and-deploy.yml) | Playbook 3: Connects all 3 servers to your GitHub repo (`https://github.com/kyawzinIT99/IT-Manger-project-.git`), clones/pulls the code to `/opt/northpoint-git-repo`, and writes `git-connection-report.txt` to `./test-outputs/`. |
| [`tmux-flip-servers.sh`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/tmux-flip-servers.sh) | Launches `tmux` on your MacBook to view all 3 servers at once or flip between them with shortcuts. |

---

## 🚀 3. Step-by-Step Commands (Run in Your Terminal)

### Step 1: Go to the `Ansible` folder and check tools on your MacBook
```bash
cd "/Users/berry/Antigravity/IT Manager project /Ansible"
```
Make sure `ansible`, `sshpass` (needed for password SSH in Ansible), and `tmux` are installed on your MacBook:
```bash
brew install ansible tmux hudochenkov/sshpass/sshpass
```

### Step 2: Build and Start the 3 Ubuntu Servers in Docker
```bash
docker compose up -d --build
```
Check that all 3 servers are running:
```bash
docker compose ps
```

### Step 3: Test Ansible Connection to All 3 Servers (`ping` module)
```bash
ansible all -m ping
```
You should see green **`SUCCESS` (`"pong"`)** from `server1`, `server2`, and `server3`!

### Step 4: Run Playbook 1 (Install `tmux` & DevOps Tools on All 3 Servers)
```bash
ansible-playbook 01-setup-tmux-and-tools.yml
```

### Step 5: Run Playbook 2 (Network Audit + Server Backup into `./test-outputs/`)
```bash
ansible-playbook 02-network-and-backup-test.yml
```
Now check the local `./test-outputs/` directory right inside your `Ansible` folder:
```bash
ls -la test-outputs/ test-outputs/server1/ test-outputs/server2/ test-outputs/server3/
```

---

## 🖥️ 4. How to Flip Between the 3 Servers Using `tmux` on Your MacBook

### Option A: Use our Ready-Made `tmux` Launcher Script
```bash
chmod +x tmux-flip-servers.sh
./tmux-flip-servers.sh
```
*(When asked for password in any pane, type: `northpoint` — or install SSH keys with `ssh-copy-id -p 2221 ansible@127.0.0.1` so it never asks!)*

### Option B: Keyboard Shortcuts Inside `tmux` to Flip Servers

Once inside `tmux`, the **Prefix key** is **`Ctrl + b`** (press `Ctrl` and `b` together, release both, then press the next key):

| Shortcut (`Ctrl + b` then...) | What It Does |
| :--- | :--- |
| **`Ctrl + b` then `↑` / `↓`** | **Flip between Server 1, Server 2, and Server 3 panes** in the split view (or just click any pane with your mouse!). |
| **`Ctrl + b` then `z`** | **Zoom / Full-screen** the current server pane (press `Ctrl + b` then `z` again to unzoom back to all 3 servers). |
| **`Ctrl + b` then `0`** | Switch to Window 0 (**All 3 Servers Split Screen**). |
| **`Ctrl + b` then `1`** | Flip to Window 1 (**`server1-web`** full screen). |
| **`Ctrl + b` then `2`** | Flip to Window 2 (**`server2-app`** full screen). |
| **`Ctrl + b` then `3`** | Flip to Window 3 (**`server3-db`** full screen). |
| **`Ctrl + b` then `n` / `p`** | Flip to the **Next (`n`)** or **Previous (`p`)** server window. |
| **`Ctrl + b` then `:setw synchronize-panes`** | **Magic DevOps Trick:** Everything you type on your MacBook is typed into **all 3 servers at the exact same time**! |
| **`Ctrl + b` then `d`** | **Detach** from `tmux` (leaves the 3 server sessions running in the background; come back anytime with `tmux attach`). |

