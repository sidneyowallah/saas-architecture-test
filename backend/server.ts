import Fastify from 'fastify';
import cors from '@fastify/cors';
import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { securityLogs } from './schema.js';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import 'dotenv/config';

const app = Fastify({ logger: true });
const allowedOrigins = process.env.FRONTEND_URL ? process.env.FRONTEND_URL.split(',') : '*';
app.register(cors, { origin: allowedOrigins });

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const db = drizzle(pool);

// Setup JWKS Client to fetch public keys from Keycloak dynamically
const keycloakUrl = process.env.KEYCLOAK_URL || 'http://localhost:8081';
const client = jwksClient({
  jwksUri: `${keycloakUrl}/realms/saas-realm/protocol/openid-connect/certs`,
});

function getKey(header: any, callback: any) {
  client.getSigningKey(header.kid, (err, key) => {
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
}

// Global Auth & Multi-Tenancy Middleware
app.addHook('preHandler', (request, reply, done) => {
  // Allow AWS ALB and monitoring tools to health-check the server without JWT tokens
  if (request.url.startsWith('/health')) {
    return done();
  }

  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return reply.status(401).send({ error: 'Missing or Invalid Token' });
  }

  const token = authHeader.split(' ')[1];
  if (!token) {
    return reply.status(401).send({ error: 'Missing Token Payload' });
  }

  // Verify the JWT cryptographically against Keycloak
  jwt.verify(token, getKey, {}, (err, decoded: any) => {
    if (err) {
      return reply.status(401).send({ error: 'Unauthorized Token' });
    }

    // Extract the custom claim we mapped in Keycloak
    const tenantId = decoded.tenant_id;

    if (!tenantId) {
      return reply.status(403).send({ error: 'No tenant_id assigned to user' });
    }

    if (!/^[a-zA-Z0-9_]+$/.test(tenantId)) {
      return reply.status(403).send({ error: 'Invalid tenant_id format' });
    }

    // Attach to the request so routes can use it safely
    (request as any).tenantId = tenantId;
    done();
  });
});

async function withTenant<T>(tenantId: string, callback: () => Promise<T>) {
  const pgClient = await pool.connect();
  try {
    await pgClient.query(`SET search_path TO ${tenantId}`);
    return await callback();
  } finally {
    await pgClient.query(`SET search_path TO public`);
    pgClient.release();
  }
}

app.get('/health', async (request, reply) => {
  return { status: 'healthy', timestamp: new Date().toISOString() };
});

app.get('/logs', async (request, reply) => {
  const tenantId = (request as any).tenantId;
  const logs = await withTenant(tenantId, async () => {
    return await db.select().from(securityLogs);
  });
  return { logs };
});

app.post('/logs', async (request, reply) => {
  const tenantId = (request as any).tenantId;
  const { event, ipAddress } = request.body as any;

  await withTenant(tenantId, async () => {
    await db.insert(securityLogs).values({ event, ipAddress });
  });
  return { success: true };
});

// Bind to 0.0.0.0 so AWS Fargate can accept external traffic
app.listen({ port: 8080, host: '0.0.0.0' }, (err, address) => {
  if (err) throw err;
  console.log(`Backend listening at ${address}`);
});
