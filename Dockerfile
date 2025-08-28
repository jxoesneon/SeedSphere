## SeedSphere Stremio Addon - Multi-stage build with Vue configure UI

# --- builder: build Vue app ---
FROM node:24-alpine AS builder
WORKDIR /app

# Install frontend deps and build configure UI
COPY configure-ui/package.json configure-ui/package-lock.json ./configure-ui/
RUN cd configure-ui && npm ci
COPY configure-ui ./configure-ui
RUN cd configure-ui && npm run build

# --- runtime: node server + static assets ---
FROM node:24-alpine
WORKDIR /app

ENV NODE_ENV=production

# Install server deps
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Copy the rest of the repository (server code, public, lib, etc.)
COPY . .

# Replace /public/configure with built assets
RUN rm -rf /app/public/configure && mkdir -p /app/public/configure && \
    cp -R /app/configure-ui/dist/* /app/public/configure/

# Default local port; Fly injects PORT
EXPOSE 55025

CMD ["node", "server.js"]
