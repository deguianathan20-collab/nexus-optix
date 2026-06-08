const crypto = require('crypto');
const { getSettings, saveSettings, storeInfo } = require('./_cmsStore');

const COOKIE_NAME = 'nexus_admin_session';
const SESSION_TTL_MS = 8 * 60 * 60 * 1000;

function adminPassword() {
  return process.env.ADMIN_PASSWORD || process.env.NEXUS_ADMIN_PASSWORD || '';
}

function sessionSecret() {
  return process.env.ADMIN_SESSION_SECRET || adminPassword();
}

function parseCookies(req) {
  const header = req.headers.cookie || '';
  return Object.fromEntries(
    header
      .split(';')
      .map((part) => part.trim())
      .filter(Boolean)
      .map((part) => {
        const index = part.indexOf('=');
        return [part.slice(0, index), decodeURIComponent(part.slice(index + 1))];
      })
  );
}

function sign(value) {
  return crypto.createHmac('sha256', sessionSecret()).update(value).digest('hex');
}

function safeEqual(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

function createSessionCookie(req) {
  const expiresAt = Date.now() + SESSION_TTL_MS;
  const value = `${expiresAt}.${sign(String(expiresAt))}`;
  const isHttps = process.env.VERCEL || req.headers['x-forwarded-proto'] === 'https';
  return `${COOKIE_NAME}=${encodeURIComponent(value)}; Path=/; Max-Age=${SESSION_TTL_MS / 1000}; HttpOnly; SameSite=Lax${isHttps ? '; Secure' : ''}`;
}

function clearSessionCookie(req) {
  const isHttps = process.env.VERCEL || req.headers['x-forwarded-proto'] === 'https';
  return `${COOKIE_NAME}=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax${isHttps ? '; Secure' : ''}`;
}

function isAuthenticated(req) {
  if (!adminPassword() || !sessionSecret()) return false;
  const value = parseCookies(req)[COOKIE_NAME];
  if (!value) return false;

  const [expiresAt, signature] = value.split('.');
  if (!expiresAt || !signature || Number(expiresAt) < Date.now()) return false;
  return safeEqual(signature, sign(expiresAt));
}

function readBody(req) {
  if (req.body && typeof req.body === 'object') return Promise.resolve(req.body);
  if (typeof req.body === 'string') {
    try {
      return Promise.resolve(JSON.parse(req.body));
    } catch (error) {
      return Promise.reject(error);
    }
  }
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 100000) {
        reject(new Error('Request body too large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function authError(res) {
  return res.status(401).json({
    success: false,
    configured: Boolean(adminPassword()),
    error: adminPassword()
      ? 'Sign in to manage site settings.'
      : 'Set ADMIN_PASSWORD or NEXUS_ADMIN_PASSWORD in Vercel environment variables before using admin.'
  });
}

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store, max-age=0');

  try {
    if (req.method === 'POST') {
      const body = await readBody(req);

      if (body.action === 'logout') {
        res.setHeader('Set-Cookie', clearSessionCookie(req));
        return res.status(200).json({ success: true });
      }

      if (body.action === 'login') {
        if (!adminPassword()) return authError(res);
        const password = String(body.password || '');
        if (!safeEqual(password, adminPassword())) {
          return res.status(401).json({ success: false, configured: true, error: 'Incorrect password.' });
        }

        res.setHeader('Set-Cookie', createSessionCookie(req));
        return res.status(200).json({ success: true });
      }
    }

    if (!isAuthenticated(req)) return authError(res);

    if (req.method === 'GET') {
      const settings = await getSettings();
      return res.status(200).json({
        success: true,
        settings,
        effectiveRecipientEmail: settings.forms.recipientEmail || process.env.MAIL_TO || '',
        store: storeInfo()
      });
    }

    if (req.method === 'PUT') {
      const body = await readBody(req);
      const settings = await saveSettings(body.settings || body);
      return res.status(200).json({
        success: true,
        settings,
        effectiveRecipientEmail: settings.forms.recipientEmail || process.env.MAIL_TO || '',
        store: storeInfo()
      });
    }

    return res.status(405).json({ success: false, error: 'Method not allowed' });
  } catch (error) {
    console.error('Admin API failed:', error.message);
    return res.status(error.statusCode || 500).json({
      success: false,
      error: error.statusCode ? error.message : 'Admin request failed'
    });
  }
};
