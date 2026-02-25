import { useState, useEffect, type FormEvent } from 'react';
import Keycloak from 'keycloak-js';

// Initialize Keycloak
// Dynamically resolve Keycloak depending on whether we are in Docker or AWS Fargate
const isLocal =
  window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
const defaultKeycloakUrl = isLocal ? 'http://localhost:8081' : `${window.location.origin}/auth`;

const keycloakUrl = import.meta.env.VITE_KEYCLOAK_URL || defaultKeycloakUrl;
const keycloak = new Keycloak({
  url: keycloakUrl,
  realm: 'saas-realm',
  clientId: 'saas-frontend',
});

let initPromise: Promise<boolean> | null = null;

function App() {
  const [authenticated, setAuthenticated] = useState(false);
  const [logs, setLogs] = useState([]);
  const [event, setEvent] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // 1. Authenticate with Keycloak on mount
  useEffect(() => {
    if (!initPromise) {
      initPromise = keycloak.init({ onLoad: 'login-required' });
    }
    initPromise.then((auth) => {
      setAuthenticated(auth);
      if (auth) {
        fetchLogs();
      }
    });
  }, []);

  const fetchLogs = async () => {
    try {
      const apiUrl = import.meta.env.VITE_API_URL || `${window.location.origin}/api`;
      const res = await fetch(`${apiUrl}/logs`, {
        headers: {
          // 2. Send the Keycloak JWT to the Fastify backend
          Authorization: `Bearer ${keycloak.token}`,
        },
      });
      const data = await res.json();
      setLogs(data.logs || []);
    } catch (error) {
      console.error('Failed to fetch logs:', error);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!event.trim()) return;

    setIsSubmitting(true);
    try {
      const apiUrl = import.meta.env.VITE_API_URL || `${window.location.origin}/api`;
      await fetch(`${apiUrl}/logs`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          // Send the Keycloak JWT on POST requests too
          Authorization: `Bearer ${keycloak.token}`,
        },
        body: JSON.stringify({ event, ipAddress: '192.168.1.50' }), // Hardcoded IP for demo
      });
      setEvent('');
      await fetchLogs();
    } catch (error) {
      console.error('Failed to submit log:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLogout = () => {
    keycloak.logout();
  };

  // Block rendering until Keycloak finishes the redirect/login flow
  if (!authenticated) {
    return (
      <div
        className="app-container"
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          height: '100vh',
        }}
      >
        <h2>Authenticating with Keycloak...</h2>
      </div>
    );
  }

  // Extract the custom claim and username directly from the decoded JWT
  const tenantId = (keycloak.tokenParsed as { tenant_id?: string })?.tenant_id || '';
  const username =
    (keycloak.tokenParsed as { preferred_username?: string })?.preferred_username || 'User';

  if (!tenantId) {
    return (
      <div
        className="app-container"
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          height: '100vh',
        }}
      >
        <h2>Error: Active User is not assigned a Tenant Org in Keycloak.</h2>
      </div>
    );
  }

  return (
    <div className="app-container">
      <header
        className="app-header"
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div>
          <h1 className="title">Security Operations Center Test</h1>
          <p className="subtitle">Real-time threat monitoring & log ingestion</p>
        </div>
        <button
          onClick={handleLogout}
          className="btn btn-primary"
          style={{ backgroundColor: '#dc3545', border: 'none' }}
        >
          Secure Logout
        </button>
      </header>

      <div className="controls-grid">
        {/* Session Info Card (Replaced the Dropdown) */}
        <section className="glass-panel">
          <div className="form-group">
            <label className="form-label">Active Session Details</label>
            <div
              style={{
                padding: '1rem',
                backgroundColor: 'rgba(0,0,0,0.03)',
                borderRadius: '8px',
                border: '1px solid rgba(0,0,0,0.1)',
              }}
            >
              <p style={{ margin: '0 0 0.5rem 0' }}>
                <strong>Operator:</strong> {username}
              </p>
              <p style={{ margin: 0, color: '#198754' }}>
                <strong>Verified Tenant DB:</strong> {tenantId}
                <span
                  style={{
                    fontSize: '0.8rem',
                    marginLeft: '8px',
                    padding: '2px 6px',
                    background: '#e8f5e9',
                    borderRadius: '12px',
                  }}
                >
                  JWT Enforced
                </span>
              </p>
            </div>
          </div>
        </section>

        {/* Ingest Form Card */}
        <section className="glass-panel">
          <form onSubmit={handleSubmit} className="ingest-form">
            <div className="form-group ingest-input">
              <label className="form-label" htmlFor="event-input">
                Manual Log Ingestion
              </label>
              <input
                id="event-input"
                type="text"
                className="input-control"
                value={event}
                onChange={(e) => setEvent(e.target.value)}
                placeholder="e.g. Unauthorized access attempt detected"
                required
                disabled={isSubmitting}
              />
            </div>
            <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
              {isSubmitting ? 'Ingesting...' : 'Ingest Log'}
            </button>
          </form>
        </section>
      </div>

      {/* Data Table Card */}
      <section className="glass-panel">
        <div style={{ marginBottom: '1.5rem' }}>
          <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>Recent Activity Feed</h3>
          <p className="subtitle" style={{ fontSize: '0.9rem' }}>
            Viewing logs securely isolated for <strong>{tenantId}</strong>.
          </p>
        </div>

        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Log ID</th>
                <th>Event Description</th>
                <th>Source IP</th>
                <th>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {logs.length === 0 ? (
                <tr>
                  <td
                    colSpan={4}
                    className="empty-state"
                    style={{ textAlign: 'center', padding: '2rem' }}
                  >
                    No security events recorded in this environment.
                  </td>
                </tr>
              ) : (
                logs.map(
                  (log: {
                    id: number | string;
                    event: string;
                    ipAddress: string;
                    createdAt: string;
                  }) => (
                    <tr key={log.id}>
                      <td>
                        <span className="log-id">{String(log.id).padStart(4, '0')}</span>
                      </td>
                      <td style={{ fontWeight: 500 }}>{log.event}</td>
                      <td>{log.ipAddress}</td>
                      <td style={{ color: 'var(--text-muted)' }}>
                        {new Date(log.createdAt).toLocaleString(undefined, {
                          dateStyle: 'medium',
                          timeStyle: 'short',
                        })}
                      </td>
                    </tr>
                  )
                )
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

export default App;
