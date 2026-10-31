# ============================================================
# Dockerfile — The "Sealed Meal Box" for Kubernetes & Cloud Run
# ============================================================
# HOW DOCKER + KUBERNETES WORK TOGETHER ("How to Cook"):
#
#   1. Dockerfile (The Recipe):
#      Defines the OS (Alpine Linux), Node.js v22, and runs
#      `npm install` so ALL dependencies are already installed
#      INSIDE the image. You never install dependencies on the
#      Kubernetes server/node itself!
#
#   2. Docker Image (The Sealed Meal Box):
#      Running `docker build -t northpoint-storefront:v1 .`
#      bakes your code + node_modules + compiled frontend into
#      one portable package.
#
#   3. Kubernetes (The Head Chef / Kitchen Manager):
#      Takes that ready-made Docker image and runs 2 to 50 copies
#      ("Pods") across servers, restarts crashed containers, and
#      balances traffic between them.
# ============================================================


# ---- STAGE 1: BUILD (Install dependencies & compile frontend) ----
FROM node:22-alpine AS build

WORKDIR /app

# Copy package files first (Docker caches this layer if dependencies don't change)
COPY package*.json ./
COPY client/package*.json ./client/

# Install ALL dependencies inside the container (Backend + Frontend)
RUN npm install
RUN cd client && npm install

# Copy the rest of the application source code
COPY . .

# Build the frontend into static production files (/app/client/dist)
RUN cd client && npm run build


# ---- STAGE 2: RUNTIME (Lean production container for Kubernetes) ----
FROM node:22-alpine AS runtime

WORKDIR /app

# Copy package files and install ONLY production dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy backend server code
COPY server/ ./server/

# Copy the compiled frontend assets from Stage 1
COPY --from=build /app/client/dist ./client/dist

# ---- ENVIRONMENT DEFAULTS ----
# Kubernetes can override these via ConfigMap (02-configmap.yaml)
ENV PORT=8080
ENV NODE_ENV=production

# ---- CONTAINER HEALTH CHECK ----
# Note: When running in Kubernetes, Kubernetes uses its own
# livenessProbe and readinessProbe (defined in 04-deployment.yaml)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -qO- http://localhost:8080/api/health || exit 1

# ---- EXPOSE PORT ----
# Document that the container listens on port 8080
EXPOSE 8080

# ---- START COMMAND ----
# Kubernetes runs this command when starting each Pod
CMD ["node", "server/index.js"]

