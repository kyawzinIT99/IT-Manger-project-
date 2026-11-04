# 🎓 Complete Docker + Kubernetes Training Guide — Northpoint Living

This guide documents **everything from our hands-on Kubernetes training session**, including every concept, diagram, question & answer, and step-by-step terminal command.

---

## 1. 👨‍🍳 How to "Cook": Docker vs. Kubernetes vs. Terraform

Think of running Northpoint Living's e-commerce platform like running a high-volume restaurant kitchen:

| Tool | Kitchen Analogy | What It Actually Does |
|------|----------------|-----------------------|
| **`Dockerfile`** | 📜 **The Recipe** | Starts with `node:22-alpine`, copies `package.json`, and runs `npm install` **inside the container** during build. Compiles the frontend (`client/dist`) and sets the start command (`node server/index.js`). |
| **Docker Image (`northpoint-storefront:v1`)** | 🍱 **The Sealed Meal Box** | Created when you run `docker build -t northpoint-storefront:v1 .`. All code + `node_modules` dependencies are sealed inside this box. **You NEVER install Node.js, PHP, or npm packages on Kubernetes servers!** |
| **Kubernetes (`kubernates/*.yaml`)** | 👨‍🍳 **The Head Chef** | Takes that sealed Docker image and runs **2 to 50 copies ("Pods")**, injects environment variables & secrets, checks `/api/health`, auto-heals crashed Pods, and load-balances customer traffic. |
| **Terraform (`Terraform/*.tf`)** | 🏗️ **The Building Contractor** | Builds the cloud infrastructure in Google Cloud (VPC network walls, Cloud SQL MySQL database, Cloud Storage buckets, Cloud Armor WAF, and Secret Manager). |

---

## 2. 🐳 Docker Fundamentals We Practiced

### A. Why Does `docker build` Require a `.` (Dot) at the End?
```bash
cd "/Users/berry/Antigravity/IT Manager project /kubernates"
docker build -t northpoint-storefront:v1 .
```
* **`-t northpoint-storefront:v1`** → Tags (names) the image `northpoint-storefront:v1`.
* **`.` (The Dot)** → Tells Docker: *"Look inside the **current folder** (`kubernates/`) for the `Dockerfile`, `package.json`, `server/`, and `client/` files."*
* Without the `.`, Docker fails with: `ERROR: 'docker buildx build' requires 1 argument`.

### B. Why Is `docker ps` Empty Right After `docker build`?
* **`docker images`** = Shows **Images (Blueprints / Sealed Meal Boxes)** sitting on the shelf.
* **`docker ps`** = Shows **actively running Containers**. `docker build` only builds the blueprint; it doesn't start a container until you run `docker run` or start a `kind` cluster.

### C. How to Find Container Names & Go Inside a Container
1. **Find container names:**
   ```bash
   docker ps
   ```
   Look at the last column (`NAMES`), e.g. `northpoint-control-plane`.
2. **Go INSIDE a running Docker container:**
   ```bash
   docker exec -it northpoint-control-plane bash
   ```
   *(Type `exit` to return to your Mac terminal).*
3. **Peek inside the `northpoint-storefront:v1` image directly:**
   ```bash
   docker run --rm -it northpoint-storefront:v1 sh
   ```

---

## 3. 🖥️ Why `kind load docker-image` Had to Copy the Image

When you run `kind create cluster --name northpoint`, `kind` (**K**ubernetes **IN** **D**ocker) creates a Docker container named `northpoint-control-plane` that simulates a real Linux server (Kubernetes Node).

```text
┌─────────────────────────────────────────────────────────────────┐
│ 💻 Room 1: Your Mac (Docker Desktop)                            │
│   `docker build` saves `northpoint-storefront:v1` HERE.         │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ 🖥️ Room 2: `northpoint-control-plane` (Kubernetes Node) │   │
│   │   Kubernetes runs INSIDE this isolated container!       │   │
│   │   It CANNOT see images sitting outside on your Mac.     │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

* **Locally on your Mac:** Running `kind load docker-image northpoint-storefront:v1 --name northpoint` copies the image from Room 1 (Mac) into Room 2 (`northpoint-control-plane`).
* **In Google Cloud (Production):** Instead of `kind load`, Cloud Build pushes the image to **Google Artifact Registry**, and Cloud Run / GKE pulls it from there.

---

## 4. 🗺️ Complete File Map: Terraform vs. Kubernetes (`kubernates/`)

### Why Do 8 YAML Files Only Create 2 Running Pods?
**Not every YAML file creates a Pod!** Only **`04-deployment.yaml`** (`replicas: 2`) creates Pods. All the other YAML files configure folders, variables, passwords, hard drives, load-balancing, and auto-scaling rules around those 2 Pods:

| File in `kubernates/` | Kind | Creates Pods? | Equivalent in `Terraform/` | What It Does |
|-----------------------|------|:-------------:|----------------------------|--------------|
| **[kustomization.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/kustomization.yaml)** | `Kustomization` | 0 Pods | `main.tf` | **Orchestrator:** Links `01` through `08` in exact order when you run `kubectl apply -k .` |
| **[main.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/main.yaml)** | All-in-One | **2 Pods** | All `.tf` files combined | **Single Master File:** Combines all resources below into one file using `---` separators (`kubectl apply -f main.yaml`). |
| **[01-namespace.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/01-namespace.yaml)** | `Namespace` | 0 Pods | `var.environment` | Creates the virtual project folder `northpoint-living`. |
| **[02-configmap.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/02-configmap.yaml)** | `ConfigMap` | 0 Pods | `variables.tf` | Stores non-secret environment variables (`PORT=8080`, `DB_HOST=10.0.0.5`, `MEDIA_BUCKET`). |
| **[03-secret.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/03-secret.yaml)** | `Secret` | 0 Pods | `secrets.tf` | Stores encrypted passwords (`DB_PASSWORD`, `JWT_SECRET`, `APP_SECRET`). |
| **[08-pvc.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/08-pvc.yaml)** | `PersistentVolumeClaim` | 0 Pods | Cloud SQL / GCS disk | Creates a permanent **5 GB hard drive** mounted at `/app/data` so data survives Pod crashes. |
| **[04-deployment.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/04-deployment.yaml)** | `Deployment` | ✅ **2 Pods** | `cloud-run.tf` | **The Boss:** Runs `replicas: 2` copies of `northpoint-storefront:v1`, mounts `/app/data`, and checks `/api/health`. |
| **[05-service.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/05-service.yaml)** | `Service` | 0 Pods | Internal Load Balancer | Gives a permanent IP & DNS (`northpoint-storefront-svc`) and load-balances traffic across all healthy Pods. |
| **[06-hpa.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/06-hpa.yaml)** | `HorizontalPodAutoscaler` | 0 Pods *(scales 2→50)* | `scaling { min=2, max=50 }` | **Auto-Scaler Robot:** Watches CPU/Memory 24/7 and automatically scales `04-deployment.yaml` between **2 and 50 Pods**. |
| **[07-ingress.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/07-ingress.yaml)** | `Ingress` | 0 Pods | Public Domain + WAF | Routes external domain traffic (`northpointliving.com`) into `05-service.yaml`. |

---

### How to Run `main.yaml` vs. `01`–`08` (`kustomization.yaml`)

| Method | Deploy Command | Delete Command | How It Works |
|--------|---------------|----------------|--------------|
| **Option A: Modular (`kustomization.yaml`)** | `kubectl apply -k .` | `kubectl delete -k .` | Reads `kustomization.yaml` and applies `01` through `08` in order. |
| **Option B: Single File (`main.yaml`)** | `kubectl apply -f main.yaml` | `kubectl delete -f main.yaml` | Reads only `main.yaml`, where `---` separates each section. |

---

## 5. ⚙️ `02-configmap.yaml` vs. 🔒 `03-secret.yaml` (Deep Dive)

### A. Why Don't We Put Database IPs or Passwords Inside the `Dockerfile`?
1. **Reusability (One Image for Dev, Staging & Prod):**
   If you hardcode `DB_HOST=10.0.0.5` inside the `Dockerfile`, you have to rebuild a separate Docker image for Dev, Staging, and Production. With `ConfigMap`, you use the **exact same `northpoint-storefront:v1` image** everywhere and only swap the `ConfigMap`!
2. **Security:**
   Anyone who pulls your Docker image can inspect every layer inside it. Putting `DB_PASSWORD` inside a `Dockerfile` exposes your database password to anyone with image access!

### B. `02-configmap.yaml` vs. `03-secret.yaml`: What Is the Difference?

| Feature | ⚙️ `02-configmap.yaml` (`ConfigMap`) | 🔒 `03-secret.yaml` (`Secret`) |
|---------|--------------------------------------|--------------------------------|
| **What goes inside?** | **Public / Non-Sensitive settings:** `PORT`, `NODE_ENV`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `MEDIA_URL` | **Private / Sensitive credentials:** `DB_PASSWORD`, `JWT_SECRET`, `APP_SECRET` |
| **How is it stored?** | Plain text (`data:`) — visible when you run `kubectl describe configmap` | Base64-encoded (`stringData:` → `data:`) — hidden as `***` bytes in `kubectl describe secret` |
| **Terraform Equivalent** | `variables.tf` / `cloud-run.tf` plain `env` | `secrets.tf` (Google Secret Manager) |

### C. How They Get Injected Into Your Pods (`04-deployment.yaml` Lines 66–70)
Look at how **[04-deployment.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/04-deployment.yaml#L66-L70)** plugs both files into your container at startup:
```yaml
          # Pulls all key-values from 02-configmap.yaml and 03-secret.yaml
          envFrom:
            - configMapRef:
                name: storefront-config
            - secretRef:
                name: storefront-secrets
```
Inside `server/index.js`, Node.js reads them automatically via `process.env.DB_HOST`, `process.env.DB_PASSWORD`, etc.!

### D. Hands-On Terminal Commands to Inspect ConfigMap & Secret:
```bash
# 1. List your ConfigMap and Secret
kubectl get configmap,secret -n northpoint-living

# 2. Compare them: ConfigMap shows plain values, Secret hides values as bytes!
kubectl describe configmap storefront-config -n northpoint-living
kubectl describe secret storefront-secrets -n northpoint-living

# 3. Prove that the running Pod received BOTH inside its environment!
kubectl exec -n northpoint-living deploy/northpoint-storefront -- sh -c "env | grep -E 'DB_|MEDIA_|JWT_|APP_'"
```

---

## 6. 🗂️ System Namespaces vs. Your Project Namespace

When you ran `kubectl get pods -n local-path-storage` and saw `local-path-provisioner`, that was one of Kubernetes's built-in system folders:

* **`kube-system`** → Built-in Kubernetes brain (DNS, networking, API server).
* **`local-path-storage`** → Built-in storage manager (`local-path-provisioner`) that creates the virtual hard drives on your Mac when you apply **`08-pvc.yaml`**!
* **`northpoint-living`** → **Your project folder!** Always add `-n northpoint-living` to check your Northpoint resources (or `-A` to see all namespaces at once).

---

## 6. 🔌 Understanding `05-service.yaml` & The 3 Ports

### A. The 3 Ports (`Mac Port` → `Service Port` → `Pod TargetPort`)
```text
  [Your Mac Browser]           [05-service.yaml]            [04-deployment.yaml Pod]
  localhost:9090  ─────────►     port: 80      ─────────►     targetPort: 8080
   (LEFT number)                (RIGHT number)               (Inside Dockerfile)
```
When you run:
```bash
kubectl port-forward svc/northpoint-storefront-svc 9090:80 -n northpoint-living
```
* **LEFT number (`9090`):** The port opened on **your Mac** (`http://localhost:9090`). If `8080` is already used by another app on your Mac, change the LEFT number to `9090` or `3000`.
* **RIGHT number (`80`):** Matches `port: 80` in `05-service.yaml`.
* **`targetPort: 8080`:** Matches `EXPOSE 8080` inside your isolated Docker container.

### B. Why Do We Need `05-service.yaml`? (2 Main Objectives)
1. **Consistent Speed Under Heavy Traffic Load (Load Balancing):**
   When you scaled from 2 Pods to 5 Pods, `05-service.yaml` used `selector: app: storefront` to automatically discover all 5 Pod IPs (`Endpoints`) and split customer requests evenly across all 5 Pods.
2. **Consistent Address When Pods Die or Scale (Zero Downtime):**
   Every time a Pod crashes or scales, it gets a brand-new IP (`10.244.0.x`). `05-service.yaml` provides one **unchanging IP and DNS name (`northpoint-storefront-svc`)** and immediately stops sending traffic to any Pod that fails `/api/health`.

---

## 7. 🔄 Why Deleted Pods Come Back Automatically (Self-Healing Hierarchy)

When you ran `kubectl delete pod ...` (or `kubectl delete pods --all`), Kubernetes immediately created brand-new Pods (`AGE: 1s`) without you running `docker build` or `kubectl apply` again!

### Why? Because of the 3-Level Hierarchy:
```text
  👔 1. THE BOSS: Deployment (`04-deployment.yaml`)
        Rule: "Always keep `replicas: 2` Pods running!"
             │
             ▼
  📋 2. THE SUPERVISOR: ReplicaSet
        Checks every second: "Desired = 2 | Actual = 0 -> Spawn 2 new Pods now!"
             │
             ├──► 📦 3. WORKER: Pod 1 (Starts in <1s from cached `northpoint-storefront:v1` image)
             └──► 📦 3. WORKER: Pod 2 (Starts in <1s from cached `northpoint-storefront:v1` image)
```
* Deleting a **Pod** only deletes the worker at the bottom — **The Boss (`Deployment`)** is still alive and immediately spawns a replacement!
* **How to actually stop Pods permanently:** Delete the Boss (`kubectl delete deployment northpoint-storefront -n northpoint-living` or `kubectl delete -k .`).

### 7.1 ⚖️ Stateless Workloads vs. Stateful Workloads: The Architecture of Self-Healing

An essential concept for an IT Manager and Lead DevOps Architect is understanding that **not all self-healing behaves the same**:

| Architectural Dimension | 🌐 Stateless Workloads (e.g. Nginx, Vite/React Frontend, API Gateways) | 💾 Stateful Workloads (e.g. MySQL, Redis, Storefront Auth Database) |
| :--- | :--- | :--- |
| **Storage Dependency** | **Zero Storage Needed** (No PVC or external volume) | **Strictly Dependent on PVC (`08-pvc.yaml`)** |
| **Data Nature** | Ephemeral, read-only container image, processes requests in-memory | Persistent, stores transaction logs, user accounts, shopping carts |
| **Self-Healing Mechanism** | Pod crashes $\rightarrow$ ReplicaSet launches new Pod $\rightarrow$ **Instantly operational in <2s** | Pod crashes $\rightarrow$ ReplicaSet launches new Pod $\rightarrow$ **Requires Volume Re-attachment** |
| **What Happens Without PVC?** | **Zero impact.** The new Pod starts clean and serves requests seamlessly. | **Catastrophic Data Loss.** Pod starts empty; all user accounts are permanently wiped! |
| **Scheduler Dependency** | Pod can be scheduled on **any healthy node** immediately. | Pod **CANNOT START** if PVC is unbound or missing (Stuck in `Pending: FailedScheduling`). |
| **K8s Controller Best Practice** | `Deployment` (`04-deployment.yaml`) | `StatefulSet` (`09-mysql-statefulset.yaml`) or Deployment with dedicated PVC mount |

#### The IT Manager Executive Principle:
> **"For Stateless Workloads, self-healing is purely compute replacement. For Stateful Workloads, self-healing is a two-part contract: Compute Replacement + Volume Re-attachment. Without storage decoupling via Persistent Volumes, self-healing is an illusion because data loss is guaranteed."**

---

## 8. 📈 How `06-hpa.yaml` Auto-Scales at 2:00 AM

Instead of a human typing `kubectl scale --replicas=5`, **`06-hpa.yaml` (`HorizontalPodAutoscaler`)** watches your Pods 24/7:
* **`minReplicas: 2`** → Always keeps at least 2 Pods running for High Availability.
* **`maxReplicas: 50`** → Caps scaling at 50 Pods to handle 10× flash sales while protecting your budget.
* **`averageUtilization: 70` (CPU) / `80` (Memory)** → Scales up immediately (`stabilizationWindowSeconds: 0`) when CPU > 70%, and waits 5 minutes (`300s`) after traffic drops before scaling down (`Terminating` extra Pods).

---

## 9. 💾 Volumes (`08-pvc.yaml`): Why Data Disappears Without a Volume

* **Without a Volume:** Pod disks are temporary. When a Pod crashes or terminates, **100% of files written inside the container are wiped forever**.
* **With `08-pvc.yaml` (`northpoint-data-pvc`):** Mounts a permanent 5 GB hard drive to `/app/data` inside the container. When old Pods die and new Pods start, Kubernetes automatically re-attaches `/app/data` to the new Pods so **zero data is lost**.

### Commands to Verify & Test Your Volume:
```bash
# 1. Check that the 5Gi volume is Bound
kubectl get pvc,pv -n northpoint-living

# 2. Check the mounted /app/data disk inside the Pod
kubectl exec -n northpoint-living deploy/northpoint-storefront -- df -h /app/data

# 3. Write a test order to /app/data/order-101.txt
kubectl exec -n northpoint-living deploy/northpoint-storefront -- sh -c "echo 'Order #101: HKD 4,800 Oak Table' > /app/data/order-101.txt"

# 4. Destroy ALL Pods (Deployment automatically spawns fresh Pods)
kubectl delete pods --all -n northpoint-living && sleep 5 && kubectl get pods -n northpoint-living

# 5. Read the file from the brand-new Pod — it survived!
kubectl exec -n northpoint-living deploy/northpoint-storefront -- cat /app/data/order-101.txt
```

---

## 10. 🚀 Master Command Cheat Sheet (Start to Finish)

```bash
# 1. Go to the kubernates folder
cd "/Users/berry/Antigravity/IT Manager project /kubernates"

# 2. Build the Docker image (bakes code + npm dependencies inside)
docker build -t northpoint-storefront:v1 .

# 3. Create the local Kubernetes cluster
kind create cluster --name northpoint

# 4. Copy the built Docker image into the Kubernetes cluster node
kind load docker-image northpoint-storefront:v1 --name northpoint

# 5. Deploy all Kubernetes files (via kustomization.yaml OR main.yaml)
kubectl apply -k .
# (Alternative: kubectl apply -f main.yaml)

# 6. Check all resources (Deployment, ReplicaSet, Pods, Service, HPA, Ingress, PVC)
kubectl get deploy,rs,pods,svc,hpa,ingress,pvc -n northpoint-living -o wide

# 7. Check Service load-balancer Endpoints (Pod IPs)
kubectl describe svc northpoint-storefront-svc -n northpoint-living

# 8. Open local port 9090 -> http://localhost:9090
kubectl port-forward svc/northpoint-storefront-svc 9090:80 -n northpoint-living

# 9. Clean up / Delete everything when finished practicing
kubectl delete -k .
kind delete cluster --name northpoint
```
---

## 11. 🔐 How to Create & Control Admin Passwords and User Passwords

There are **two ways** to create and control Admin & User passwords in Kubernetes:

### Way 1: In `03-secret.yaml` (Master Bootstrap Admin & Staff Passwords)
Look inside **[03-secret.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/03-secret.yaml#L33-L41)**:
```yaml
  # ---- ADMIN & USER LOGIN CREDENTIALS (To Control the App) ----
  ADMIN_USERNAME: "admin@northpointliving.com"
  ADMIN_PASSWORD: "Admin@Northpoint2026!"

  # Default Customer / Staff User Account
  USER_USERNAME: "staff@northpointliving.com"
  USER_PASSWORD: "Staff@Northpoint2026!"
```
* **How it works:** Kubernetes encrypts these in `storefront-secrets` and injects them into your container as `process.env.ADMIN_PASSWORD` and `process.env.USER_PASSWORD`.
* **How to change the Admin Password anytime (Zero Docker Rebuild!):**
  1. Edit `ADMIN_PASSWORD` in `03-secret.yaml` (or `main.yaml`).
  2. Apply the updated secret and restart the Pods so they pick up the new password:
     ```bash
     kubectl apply -f 03-secret.yaml
     kubectl rollout restart deployment northpoint-storefront -n northpoint-living
     ```

### Way 2: Inside the App / Persistent Volume (`/app/data/users.json` on `08-pvc.yaml`)
When the Admin creates new customer or staff accounts through the `/api/users` API (or the **Admin Control Panel** at `http://localhost:9090`), the app checks `ADMIN_PASSWORD` (from `03-secret.yaml`) and saves the new users permanently inside `/app/data/users.json` on your **5 GB Persistent Volume (`08-pvc.yaml`)** so they survive Pod crashes and restarts!

### How to Check All Users & Passwords + Log In on Local Port (`http://localhost:9090`):

```bash
# 1. Check the Admin & Staff User passwords injected from 03-secret.yaml:
kubectl exec -n northpoint-living deploy/northpoint-storefront -- sh -c "env | grep -E 'ADMIN_|USER_'"

# 2. Check any additional users saved on the 5GB Persistent Volume (/app/data/users.json):
kubectl exec -n northpoint-living deploy/northpoint-storefront -- sh -c "cat /app/data/users.json 2>/dev/null || echo 'No custom volume users yet'"

# 3. Rebuild image with the Login UI, load into kind, and restart Pods:
cd "/Users/berry/Antigravity/IT Manager project /kubernates"
docker build -t northpoint-storefront:v1 .
kind load docker-image northpoint-storefront:v1 --name northpoint
kubectl apply -k .
kubectl rollout restart deployment northpoint-storefront -n northpoint-living

# 4. Open local port 9090 and log in via browser at http://localhost:9090:
kubectl port-forward svc/northpoint-storefront-svc 9090:80 -n northpoint-living
```



---

## 12. 🧭 Future Learning Roadmap (Next Steps After This Lab)

You have already mastered the core foundation of **Docker + Kubernetes + Terraform**. Here are the **5 next topics** to learn as an IT Manager / DevOps & Cloud Architect:

### Level 1: What You Have Already Mastered ✅
* **Docker:** Multi-stage `Dockerfile`, baking `npm` dependencies inside images, inspecting containers (`docker exec -it`).
* **Kubernetes (`kubernates/`):** `Namespace`, `ConfigMap`, `Secret`, `Deployment` (Boss) → `ReplicaSet` (Supervisor) → `Pods` (Workers), `Service` (`Endpoints`), `HPA` (2→50 auto-scaling), `Ingress`, and `PersistentVolumeClaim` (`/app/data`).
* **Terraform (`Terraform/`):** GCP `VPC`, `Cloud SQL MySQL`, `Cloud Run`, `Cloud Armor WAF`, `Secret Manager`, and `IAM`.

---

### Level 2: `StatefulSet` — Running Real Databases Inside Kubernetes (`09-mysql-statefulset.yaml`) 🗄️
* **File created:** **[09-mysql-statefulset.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/09-mysql-statefulset.yaml)** (Equivalent to `Terraform/cloud-sql.tf`)
* **Why `StatefulSet` instead of `Deployment` for MySQL?**
  1. **Fixed Pod Identity (`mysql-0`, `mysql-1`):** A `Deployment` gives Pods random names (`northpoint-storefront-5cc7b...`). A `StatefulSet` gives Pods permanent, numbered names (`mysql-0` is ALWAYS the Primary database!).
  2. **Ordered Startup:** Starts `mysql-0` first, waits until it passes `mysqladmin ping`, and only then starts `mysql-1`.
  3. **Dedicated Hard Drive Generator (`volumeClaimTemplates`):** Automatically creates a dedicated 5 GB `PersistentVolumeClaim` named **`mysql-data-mysql-0`** mounted at `/var/lib/mysql`.
* **Commands to deploy & connect to MySQL (`mysql-0`):**
  ```bash
  # 1. Deploy the MySQL StatefulSet
  kubectl apply -f 09-mysql-statefulset.yaml

  # 2. Watch mysql-0 start up (notice the name is fixed: mysql-0!)
  kubectl get statefulset,pods,pvc -n northpoint-living

  # 3. Open a live SQL shell inside mysql-0 using the password from 03-secret.yaml!
  kubectl exec -it mysql-0 -n northpoint-living -- sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" northpoint'
  ```

---

### Level 3: Monitoring Software in Kubernetes — Prometheus (`10-monitoring.yaml`) 📊
* **File created:** **[10-monitoring.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/10-monitoring.yaml)** (Equivalent to `Terraform/monitoring.tf`)
* **What it is:** In Google Cloud (`monitoring.tf`), Cloud Monitoring checks `/api/health` every 60s. In Kubernetes, the standard monitoring software is **Prometheus**.
* **How `10-monitoring.yaml` works:**
  1. `ConfigMap (prometheus-config)`: Configures Prometheus to scrape `northpoint-storefront-svc:80/api/health` every **15 seconds**.
  2. `Deployment (northpoint-prometheus)`: Runs `prom/prometheus:v2.53.0`.
  3. `Service (northpoint-prometheus-svc)`: Exposes the Prometheus Web Dashboard on port `9090`.
* **Commands to launch & view Prometheus Monitoring Dashboard:**
  ```bash
  # 1. Deploy Prometheus monitoring
  kubectl apply -f 10-monitoring.yaml

  # 2. Check that the Prometheus Pod is 1/1 Running
  kubectl get pods -l app=prometheus -n northpoint-living

  # 3. Open the Prometheus Web UI on localhost:9091 -> http://localhost:9091/targets
  kubectl port-forward svc/northpoint-prometheus-svc 9091:9090 -n northpoint-living
  ```


---

### Level 3: Helm — The "App Store / Package Manager" for Kubernetes ⎈
* **What to learn next:** Just like `brew` on macOS or `npm` in Node.js, **Helm** lets you install complex software (like **n8n**, **MySQL**, **Redis**, or **Nginx Ingress**) into Kubernetes with **1 command** instead of writing 20 YAML files by hand:
  ```bash
  helm install my-n8n oci://8gears.container-registry.com/library/n8n
  ```
* **Why it matters:** Helm also lets you turn your `01`–`08` YAML files into a reusable template with a single `values.yaml` file (just like `terraform.tfvars`!).

---

### Level 4: CI/CD & GitOps (GitHub Actions + Cloud Build + ArgoCD) 🔄
* **What to learn next:** Right now, you run `docker build`, `kind load`, and `kubectl apply` manually in your terminal.
* **With CI/CD (`cloudbuild.yaml` / GitHub Actions) + ArgoCD:**
  1. Developer pushes code to GitHub (`git push`).
  2. Pipeline automatically runs tests and builds `northpoint-storefront:v2`.
  3. **ArgoCD** (running inside Kubernetes) detects the Git change and automatically updates the cluster with zero downtime!

---

### Level 5: Production Monitoring & Secret Sync (Prometheus, Grafana & External Secrets) 📊
* **Prometheus + Grafana:** Visual dashboards inside Kubernetes showing live CPU, RAM, request latency, and Pod scaling graphs.
* **External Secrets Operator (Connecting Terraform + Kubernetes):** Automatically syncs passwords from **Google Secret Manager (`Terraform/secrets.tf`)** directly into **Kubernetes (`03-secret.yaml`)** so you never have to type passwords in YAML files!

---

### Level 4: Visual Executive Dashboards — Grafana (`11-grafana.yaml`) 📈
* **File created:** **[11-grafana.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/11-grafana.yaml)**
* **How Prometheus + Grafana work together:**
  * **Prometheus (`10-monitoring.yaml`)** collects and stores the numbers every 15 seconds.
  * **Grafana (`11-grafana.yaml`)** automatically connects to `http://northpoint-prometheus-svc:9090` and turns those numbers into visual executive dashboards!
  * It uses your `ADMIN_PASSWORD` (`Admin@Northpoint2026!`) directly from `03-secret.yaml`!
* **Commands to deploy & open Grafana:**
  ```bash
  # 1. Deploy Grafana
  kubectl apply -f 11-grafana.yaml

  # 2. Wait until the Grafana Pod is 1/1 Running
  kubectl get pods -l app=grafana -n northpoint-living

  # 3. Open Grafana on localhost:3000 -> http://localhost:3000
  #    Login: Username = admin | Password = Admin@Northpoint2026!
  kubectl port-forward svc/northpoint-grafana-svc 3000:3000 -n northpoint-living
  ```

---

### Level 5: `07-ingress.yaml` — The Public HTTPS Front Door 🌐
* **File:** **[07-ingress.yaml](file:///Users/berry/Antigravity/IT%20Manager%20project%20/kubernates/07-ingress.yaml)**
* **Why do we need `07-ingress.yaml` when we already have `05-service.yaml`?**
  * **`05-service.yaml` (`type: ClusterIP`)** is an **INTERNAL** load balancer. It only works inside the Kubernetes cluster (which is why you had to run `kubectl port-forward` on your Mac to reach it). Real customers on the internet cannot run `kubectl port-forward`!
  * **`07-ingress.yaml` (`kind: Ingress`)** is the **EXTERNAL Front Door** that exposes your internal Services to the public internet under a real domain name (`https://northpointliving.com`)!
* **How `07-ingress.yaml` saves money (1 Load Balancer for Multiple Services):**
  Instead of paying Google Cloud for 3 separate Load Balancers (one for Storefront, one for Grafana, one for Prometheus), **one single Ingress** routes different domains or URL paths to different internal Services:
  ```text
  Internet Customer (https://northpointliving.com)
         │
         ▼
  🌐 [07-ingress.yaml] (Single Public IP + SSL Certificate + Cloud Armor WAF)
         ├──► Host: northpointliving.com         ──► [05-service.yaml] (Storefront :80)
         └──► Host: monitor.northpointliving.com ──► [11-grafana.yaml] (Grafana :3000)
  ```
* **Commands to inspect your Ingress:**
  ```bash
  kubectl get ingress -n northpoint-living
  kubectl describe ingress northpoint-storefront-ingress -n northpoint-living
  ```
