const { Pool } = require('pg');
let pool;
module.exports = {
  query: (text, params) => pool.query(text, params),
  connect: async () => {
    if (!pool) {
      pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
    }
    return pool.connect();
  }
};