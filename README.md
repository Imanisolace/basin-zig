# basin-zig
```markdown
# Basin

**Fast Merkle proof generation API with Poseidon support**

Basin is a high-performance API for generating and verifying Merkle proofs.  
Built with Zig (compiled to WebAssembly) and Node.js, it is designed for cases where common JavaScript libraries become too slow or memory-heavy — especially with larger leaf sets or when Poseidon hashing is required.

---

## Why Basin?

Most popular Merkle libraries (merkletreejs, OpenZeppelin, etc.) work well for small trees but start to struggle when:

- You have tens of thousands of leaves
- You need **Poseidon** instead of keccak/sha256
- You want to offload proof generation to a service instead of running it in your own process

Basin solves these problems with a simple HTTP API.

---

## Features

- Fast proof generation (Zig → WASM)
- Poseidon hash support
- Support for larger leaf sets
- Simple REST API
- API key authentication
- Usage tracking
- Concurrent request handling via worker pool

---

## Quick Start

### 1. Get an API key

```bash
curl -X POST https://your-basin-url/apikey
```

### 2. Generate a Merkle proof

```bash
curl -X POST https://your-basin-url/prove \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "items": [
      "0xabc123...",
      "0xdef456...",
      "0x789abc..."
    ],
    "target_index": 1
  }'
```

### Example Response

```json
{
  "root": "0x...",
  "proof": {
    "steps": [
      {
        "is_right": false,
        "has_sibling": true,
        "sibling": "0x..."
      }
    ]
  }
}
```

### 3. Verify a proof

```bash
curl -X POST https://your-basin-url/verify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "item": "0xdef456...",
    "root": "0x...",
    "proof": {
      "steps": [...]
    }
  }'
```

---

## API Endpoints

| Method | Endpoint     | Description                     |
|--------|--------------|---------------------------------|
| POST   | `/apikey`    | Create a new API key            |
| POST   | `/prove`     | Generate a Merkle proof         |
| POST   | `/verify`    | Verify a Merkle proof           |
| GET    | `/usage`     | Check usage for your API key    |

---

## Tech Stack

- **Zig** – Core Merkle + Poseidon logic (compiled to WASM)
- **Node.js** – API server + worker pool
- **WebAssembly** – High-performance proof generation
- **PostgreSQL** – API key & usage storage

---

## Self-Hosting

```bash
git clone <your-repo>
cd basin-zig
npm install
zig build
npm start
```

Make sure you have Zig installed and a Postgres database configured.

---

## When to use Basin

| Use case                          | Good fit? |
|-----------------------------------|-----------|
| Small trees (< a few thousand leaves) | Optional |
| Large trees                       | Yes |
| Need Poseidon hashing             | Yes |
| Want a simple hosted API          | Yes |
| Prefer fully self-hosted library  | No |

---

## License

MIT

---

Built for teams that have outgrown the common JavaScript Merkle libraries.
```