# STAGE 1: Build Zig WASM
FROM ziglang/zig:0.14.0-alpine AS zigbuild

WORKDIR /app
COPY build.zig ./
COPY src ./src
RUN zig build --summary all

# STAGE 2: Run Node API - use alpine to keep image < 200MB
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .
COPY --from=zigbuild /app/zig-out/bin/basin.wasm /app/basin.wasm

EXPOSE 8080

CMD ["node", "server.js"]