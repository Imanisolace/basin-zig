import pkg from 'pg';
const { Pool } = pkg;

// Create pool immediately on boot
const pool = new Pool({ 
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const query = (text, params) => pool.query(text, params);

const connect = async () => {
  return pool.connect();
};

// Optional: log if we can connect
pool.connect()
  .then(client => {
    console.log('✅ Connected to Postgres');
    client.release();
  })
  .catch(err => console.error('❌ DB Connection Error', err));

export default { query, connect };