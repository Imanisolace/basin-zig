# STAGE 1: Build Zig WASM
FROM ghcr.io/ziglang/zig:0.14.0 AS zigbuild

WORKDIR /app

# Copy only what zig needs to cache layers
COPY build.zig ./
COPY src ./src

# Build release WASM. optimize is set in build.zig
RUN zig build --summary all

# STAGE 2: Run Node API
FROM node:20-slim

WORKDIR /app

# Install prod deps only
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy app code: server.js, worker.js, package.json
COPY . .

# Copy compiled WASM from builder stage
# This path must match where worker.js loads it: path.join(__dirname, 'basin.wasm')
COPY --from=zigbuild /app/zig-out/bin/basin.wasm /app/basin.wasm

# Railway sets $PORT env var. We default to 8080
EXPOSE 8080

# Healthcheck for Railway
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 8080) + '/health', (r) => {if (r.statusCode !== 200) process.exit(1)})"

# Start the API
CMD ["node", "server.js"]