# STAGE 1: Build Zig WASM
FROM alpine:latest AS zigbuild

ARG ZIG_VERSION=0.14.0
RUN apk add --no-cache curl xz tar
RUN curl -L https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz | tar -xJ
ENV PATH="/zig-linux-x86_64-${ZIG_VERSION}:$PATH"

WORKDIR /app
COPY build.zig ./
COPY src ./src
RUN zig build --summary all

# STAGE 2: Run Node API
FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY .  # <-- THIS IS LINE 24. Note the 2 dots

COPY --from=zigbuild /app/zig-out/bin/basin.wasm /app/basin.wasm

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 8080) + '/health', (r) => {if (r.statusCode !== 200) process.exit(1)})"

CMD ["node", "server.js"]