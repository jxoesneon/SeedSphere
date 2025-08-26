# SeedSphere Stremio Addon - Fly.io compatible image
FROM node:20-alpine

WORKDIR /app

# Copy full source (remote builder context may miss globbed package files otherwise)
COPY . .

# Install only production deps
RUN npm install --omit=dev

ENV NODE_ENV=production
# App listens on 55025 by default; Fly will inject PORT but we keep this for local
EXPOSE 55025

CMD ["node", "server.js"]
