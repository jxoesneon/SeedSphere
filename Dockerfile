# SeedSphere Stremio Addon - Fly.io compatible image (root)
FROM node:20-alpine

WORKDIR /app

# Copy full source
COPY . .

ENV NODE_ENV=production
# Install only production deps
RUN npm install --omit=dev

# Default local port; Fly injects PORT
EXPOSE 55025

CMD ["node", "server.js"]
