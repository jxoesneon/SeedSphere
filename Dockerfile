# SeedSphere - Fly.io compatible image (multi-stage)

# --- Builder stage: install dev deps and build client ---
FROM node:22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache python3 make g++

# Install all deps to allow building
COPY package.json package-lock.json ./
# Avoid failing on peer dependency conflicts in container
ENV npm_config_legacy_peer_deps=true
RUN npm install --no-audit --no-fund

# Copy the rest and build
COPY . .
RUN npm run build

# --- Runtime stage: production-only deps and runtime files ---
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV npm_config_legacy_peer_deps=true
RUN apk add --no-cache python3 make g++

# Install only production dependencies
COPY package.json package-lock.json ./
RUN npm install --omit=dev --no-audit --no-fund

# Copy server and built client
COPY --from=builder /app/server ./server
COPY --from=builder /app/dist ./dist

# Expose port; Fly sets PORT env at runtime (we set internal_port=8080)
EXPOSE 8080

CMD ["node", "server/index.js"]
