# 1. STAGE 1: Build Zig WASM
FROM ghcr.io/ziglang/zig:0.14.0 AS zigbuild
WORKDIR /app
COPY src ./src
COPY build.zig ./
RUN zig build --summary all

# 2. STAGE 2: Run Node
FROM node:20-slim
WORKDIR /app

# Install deps
COPY package*.json ./
RUN npm ci --omit=dev

# Copy app code
COPY . .

# Copy compiled Zig artifacts from stage 1
# WASM goes to public folder so node can serve it
COPY --from=zigbuild /app/zig-out/bin/basin.wasm /app/public/basin.wasm

# Expose port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {if (r.statusCode !== 200) process.exit(1)})"

# Start
CMD ["node", "server.js"]