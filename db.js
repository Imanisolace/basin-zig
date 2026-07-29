import pkg from 'pg';
const { Pool } = pkg;

let pool;

const query = (text, params) => pool.query(text, params);

const connect = async () => {
  if (!pool) {
    pool = new Pool({ 
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false }
    });
  }
  return pool.connect();
};

export default { query, connect };