# SeedSphere Stremio Addon - Fly.io compatible image (root)
FROM node:20-alpine

WORKDIR /app

# Install dependencies using lockfile (deterministic, cacheable layer)
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Copy the rest of the application
COPY . .

# Default local port; Fly injects PORT
EXPOSE 55025

CMD ["node", "server.js"]
