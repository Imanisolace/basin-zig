import pkg from 'pg';
const { Pool } = pkg;

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL not set');
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // see note above re: pinning a CA if available
});

// Without this, an async error on an idle client (DB restart, network
// blip) throws unhandled and crashes the whole process — not just the
// query that was in flight. pg.Pool already removes/replaces the bad
// client on its own; this handler just needs to exist so Node doesn't
// treat the event as fatal.
pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle Postgres client', err);
});

const query = (text, params) => pool.query(text, params);

const connect = async () => {
  return pool.connect();
};

pool.connect()
  .then(client => {
    console.log('✅ Connected to Postgres');
    client.release();
  })
  .catch(err => console.error('❌ DB Connection Error', err));

export default { query, connect };