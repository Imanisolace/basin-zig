# 1. Use official Node 20 LTS - slim for size
FROM node:20-slim

# 2. Set working dir
WORKDIR /app

# 3. Install deps - NUKE OLD CACHE FIRST
COPY package*.json ./
RUN rm -rf node_modules package-lock.json && npm cache clean --force && npm install --omit=dev

# 4. Copy app code + pre-built wasm
COPY . .

# 5. Expose port
EXPOSE 8080

# 6. Healthcheck so Railway/Fly know it's alive
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {if (r.statusCode !== 200) throw new Error()})"

# 7. Start
CMD ["node", "server.js"]