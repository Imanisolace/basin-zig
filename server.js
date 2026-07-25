const express = require('express')
const path = require('path')
const { Worker } = require('worker_threads')
const os = require('os')

const app = express()
const PORT = process.env.PORT || 8080

app.use(express.json({ limit: '10mb' }))
app.use(express.static(__dirname))

// Healthcheck
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() })
})

// Spawn workers - SAFE FOR 1GB RAM
const NUM_WORKERS = Math.min(os.cpus().length, 4)
const workers = []

console.log(`Starting ${NUM_WORKERS} workers...`)
for (let i = 0; i < NUM_WORKERS; i++) {
  const worker = new Worker(path.join(__dirname, 'worker.js'))
  worker.on('error', (err) => console.error(`Worker ${i} error:`, err))
  workers.push(worker)
}

app.get('/', (req, res) => {
  res.json({ name: 'Basin ZK API v1', status: 'live', workers: NUM_WORKERS })
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Basin ZK API v1 live on ${PORT} with ${NUM_WORKERS} workers`)
})