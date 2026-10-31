# ============================================================
# Dockerfile — Container Image for the PHP E-commerce App
# ============================================================
# This file tells Docker HOW to package our PHP application
# into a container that Cloud Run can execute.
#
# Think of a Docker container like a "shipping container" for software:
#   - Contains EVERYTHING the app needs (PHP, extensions, code, config)
#   - Runs identically everywhere (your laptop, testing, production)
#   - Cloud Run creates copies of this container to handle traffic
#
# BUILD STAGES:
#   Stage 1 (build):   Install dependencies, compile assets
#   Stage 2 (runtime): Create the final lean image to deploy
# ============================================================


# ---- STAGE 1: BUILD ----
# Install Node.js dependencies and build the frontend
FROM node:22-alpine AS build

WORKDIR /app

# Copy package files first (Docker caches this layer if they don't change)
COPY package*.json ./
COPY client/package*.json ./client/

# Install ALL dependencies (including dev dependencies for building)
RUN npm install
RUN cd client && npm install

# Copy the rest of the source code
COPY . .

# Build the frontend (Vite creates optimised static files)
RUN cd client && npm run build


# ---- STAGE 2: RUNTIME ----
# Create the final lightweight image with only what's needed to run
FROM node:22-alpine AS runtime

WORKDIR /app

# Copy package files and install ONLY production dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy server code
COPY server/ ./server/

# Copy the built frontend from Stage 1
COPY --from=build /app/client/dist ./client/dist

# ---- ENVIRONMENT ----
# Cloud Run sets the PORT environment variable automatically
ENV PORT=8080
ENV NODE_ENV=production

# ---- HEALTH CHECK ----
# Docker health check (separate from Cloud Run's probe)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -qO- http://localhost:8080/api/health || exit 1

# ---- EXPOSE PORT ----
# Tell Docker which port the app listens on
EXPOSE 8080

# ---- START COMMAND ----
# The command to run when the container starts
CMD ["node", "server/index.js"]

