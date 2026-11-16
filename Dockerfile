# syntax=docker/dockerfile:1

# ---- Stage 1: install production dependencies only ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- Stage 2: minimal runtime image ----
FROM node:22-alpine
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

# Copy dependencies and source, owned by the unprivileged built-in "node" user
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node app/package.json app/index.js ./

# Never run as root
USER node

EXPOSE 3000

# Container-level health signal (visible in `docker ps` and used by compose)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/health" || exit 1

# Run node directly (not via npm) so it receives SIGTERM for clean shutdowns
CMD ["node", "index.js"]
