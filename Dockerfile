FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

# This copies server.js, worker.js, AND basin.wasm
COPY .

EXPOSE 8080

CMD ["node", "server.js"]