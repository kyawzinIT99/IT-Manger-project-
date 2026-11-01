# 🤖 Northpoint Living — Complete Ansible Course & 3-Server Lab Guide

Everything in this lab is self-contained inside `/Users/berry/Antigravity/IT Manager project /Ansible/`. All logs, backups, and lesson verification reports are automatically saved in `./test-outputs/` inside this exact same folder.

---

## 🏗️ 1. Lab Architecture (MacBook Workstation → 3 Docker Servers)

```text
💻 YOUR MACBOOK (Local Workstation / Ansible Control Node + tmux)
 │
 ├── Reads: ansible.cfg + inventory.ini + vault-secrets.yml
 ├── Saves all logs & test files in: ./test-outputs/
 │
 ├──► SSH: 2221 | Web: http://localhost:8881 ──► 🐳 server1 (172.28.0.11) [Web Storefront 1]
 ├──► SSH: 2222 | Web: http://localhost:8882 ──► 🐳 server2 (172.28.0.12) [Web Storefront 2]
 └──► SSH: 2223 | DB : localhost:3336->3306  ──► 🐳 server3 (172.28.0.13) [MariaDB Server]
```

* **SSH Username (all 3 servers):** `ansible`
* **SSH Password (all 3 servers):** `northpoint` (defined in [`Dockerfile.node`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/Dockerfile.node) & [`inventory.ini`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/inventory.ini))

---

## 📚 2. Complete Lesson-by-Lesson Curriculum in This Folder

| Lesson / File | Core Ansible Concept Taught | Command to Run |
| :--- | :--- | :--- |
| **[`Dockerfile.node`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/Dockerfile.node)** & **[`docker-compose.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/docker-compose.yml)** | **Lab Infrastructure:** Builds 3 Ubuntu 22.04 servers with OpenSSH (`2221`, `2222`, `2223`), Web ports (`8881`, `8882`), and DB port (`3336->3306`) on subnet `172.28.0.0/16`. | `docker compose up -d --build` |
| **[`tmux-flip-servers.sh`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/tmux-flip-servers.sh)** | **Workstation Multi-Server Control:** Opens `tmux` on your MacBook with 3 side-by-side server columns + individual tabs (`Ctrl+b` then `←`/`→` or `0,1,2,3`). | `./tmux-flip-servers.sh` |
| **[`00-setup-ssh-keys.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/00-setup-ssh-keys.yml)** | **Lesson 0 — Passwordless SSH Keys:** Pushes `./ssh-keys/ansible_key.pub` to `/home/ansible/.ssh/authorized_keys` on all 3 servers so you never type passwords repeatedly. | `ansible-playbook 00-setup-ssh-keys.yml` |
| **[`01-setup-tmux-and-tools.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/01-setup-tmux-and-tools.yml)** | **Lesson 1 — Server Bootstrapping:** Installs `tmux`, `htop`, `vim`, `tree`, login banners, and `.tmux.conf` across all 3 servers. | `ansible-playbook 01-setup-tmux-and-tools.yml` |
| **[`02-network-and-backup-test.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/02-network-and-backup-test.yml)** | **Lesson 2 — Network Audit & Pre-Migration Backup:** Captures routing tables (`ip route`), open sockets (`ss -tlnp`), cross-subnet `ping`, and `.tar.gz` + `.sha256` backups. | `ansible-playbook 02-network-and-backup-test.yml` |
| **[`03-git-connect-and-deploy.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/03-git-connect-and-deploy.yml)** | **Lesson 3 — Git Integration:** Connects all 3 servers to `https://github.com/kyawzinIT99/IT-Manger-project-.git` and pulls code to `/opt/northpoint-git-repo`. | `ansible-playbook 03-git-connect-and-deploy.yml` |
| **[`04-inventory-groups-and-facts.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/04-inventory-groups-and-facts.yml)** | **Lesson 4 — Inventory Groups & Hardware/Network Facts:** Targets `all`, `[webservers]`, and `[dbservers]` separately and collects `ansible_default_ipv4` facts. | `ansible-playbook 04-inventory-groups-and-facts.yml` |
| **[`05-playbooks-and-idempotency.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/05-playbooks-and-idempotency.yml)** | **Lesson 5 — Idempotency & Multi-Tier App:** Installs MariaDB Server (`172.28.0.13:3306`) on `server3` and Nginx Web Server (`172.28.0.11/.12:80`) on `server1` & `server2`. | `ansible-playbook 05-playbooks-and-idempotency.yml` |
| **[`06-when-conditions-and-db-web-ui.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/06-when-conditions-and-db-web-ui.yml)** | **Lesson 6 — `when:` Conditions, `handlers:` & Live DB Web UI:** Uses `when:` to filter tasks in a single Play and renders live MySQL rows onto `http://localhost:8881` & `8882`. | `ansible-playbook 06-when-conditions-and-db-web-ui.yml` |
| **[`07-roles-and-vault.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/07-roles-and-vault.yml)** | **Lesson 7 — Ansible `roles/` & `ansible-vault`:** Organizes tasks into [`roles/webserver/`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/roles/webserver/tasks/main.yml) and [`roles/dbserver/`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/roles/dbserver/tasks/main.yml) and loads secrets from [`vault-secrets.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/Ansible/vault-secrets.yml). | `ansible-playbook 07-roles-and-vault.yml --ask-vault-pass` |

---

## 🌐 3. Quick Verification Commands

* **View Web Server 1 (`172.28.0.11`) Live MySQL Dashboard in Browser:** http://localhost:8881
* **View Web Server 2 (`172.28.0.12`) Live MySQL Dashboard in Browser:** http://localhost:8882
* **View Role Status Page in Browser:** http://localhost:8881/role-status.html
* **Query Database Server (`172.28.0.13:3306`) from Web Servers via Ansible:**
  ```bash
  ansible webservers -a "mysql -h 172.28.0.13 -u np_user -pnorthpoint123 -e 'SELECT * FROM northpoint_db.products;'"
  ```
* **Check All Generated Test Reports on MacBook:**
  ```bash
  ls -la test-outputs/server1/ test-outputs/server2/ test-outputs/server3/
  ```
