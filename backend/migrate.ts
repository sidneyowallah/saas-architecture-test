import { Pool } from 'pg';
import 'dotenv/config';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function runMigrations() {
  const tenants = ['tenant_a', 'tenant_b'];

  for (const tenant of tenants) {
    console.log(`Migrating schema: ${tenant}...`);
    await pool.query(`CREATE SCHEMA IF NOT EXISTS ${tenant};`);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ${tenant}.security_logs (
        id SERIAL PRIMARY KEY,
        event TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);
  }
  console.log('Migrations complete!');
  process.exit(0);
}

runMigrations();
