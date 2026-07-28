# 1. STAGE 1: Build Zig
FROM ghcr.io/ziglang/zig:0.14.0 AS zigbuild
WORKDIR /app
COPY src ./src
COPY build.zig ./
RUN zig build -Doptimize=ReleaseSafe

# 2. STAGE 2: Run Node
FROM node:20-slim
WORKDIR /app

# Install deps
COPY package*.json ./
RUN rm -rf node_modules package-lock.json && npm cache clean --force && npm install --omit=dev

# Copy app code
COPY .

# Copy compiled Zig artifacts from stage 1
COPY --from=zigbuild /app/zig-out/bin/basin-cli /app/zig-out/bin/basin-cli
COPY --from=zigbuild /app/zig-out/bin/basin.wasm /app/basin.wasm

# Make CLI executable
RUN chmod +x /app/zig-out/bin/basin-cli

# Expose port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {if (r.statusCode !== 200) throw new Error()})"

# Start
CMD ["node", "server.js"]