import { Pool } from 'pg';
import 'dotenv/config';

// Sanity-check: log the DB host (never the password) for debugging.
const dbUrl = process.env.DATABASE_URL ?? '';
if (!dbUrl) {
  console.error('❌ FATAL: DATABASE_URL environment variable is not set.');
  process.exit(1);
}
try {
  const u = new URL(dbUrl);
  console.log(`Connecting to database at: ${u.hostname}:${u.port || 5432}/${u.pathname.slice(1)}`);
} catch {
  console.error(
    '❌ FATAL: DATABASE_URL is not a valid URL:',
    dbUrl.replace(/:\/\/[^@]+@/, '://<redacted>@')
  );
  process.exit(1);
}

const pool = new Pool({
  connectionString: dbUrl,
  ssl: {
    rejectUnauthorized: false,
  },
  // Fail fast if we can't reach the DB (e.g., SG blocks port 5432).
  // Without this, the pod hangs silently until the job backoff limit is hit.
  connectionTimeoutMillis: 15_000,
  // Kill any runaway migration query after 60s.
  statement_timeout: 60_000,
});

// Guarantee all crashes are logged — even unhandled rejections.
process.on('unhandledRejection', (reason) => {
  console.error('❌ UNHANDLED REJECTION:', reason);
  process.exit(1);
});

async function runMigrations() {
  const tenants = ['tenant_a', 'tenant_b'];

  // Preflight: verify we can actually connect before looping over tenants.
  console.log('Testing database connection...');
  const client = await pool.connect();
  const { rows } = await client.query('SELECT version()');
  console.log('✅ Connected:', rows[0].version);
  client.release();

  try {
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
      console.log(`✅ Schema ${tenant} migrated.`);
    }
    console.log('✅ All migrations complete!');
    process.exit(0);
  } catch (err) {
    console.error('❌ MIGRATION FAILED:');
    console.error(err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigrations();
