const fs = require('fs/promises');
const path = require('path');

const defaults = require('./cms-defaults.json');

const STORE_KEY = 'nexus-cms-settings';
const MAX_CONTENT_LENGTH = 700;

const cloneDefaults = () => JSON.parse(JSON.stringify(defaults));

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '').trim());
}

function mergeSettings(input) {
  const base = cloneDefaults();
  const source = input && typeof input === 'object' ? input : {};
  const forms = source.forms && typeof source.forms === 'object' ? source.forms : {};
  const content = source.content && typeof source.content === 'object' ? source.content : {};

  const recipientEmail = String(forms.recipientEmail || '').trim();
  if (recipientEmail) base.forms.recipientEmail = recipientEmail;

  for (const key of Object.keys(base.content)) {
    if (Object.prototype.hasOwnProperty.call(content, key)) {
      const nextValue = String(content[key] ?? '').replace(/\s+/g, ' ').trim();
      base.content[key] = nextValue.slice(0, MAX_CONTENT_LENGTH);
    }
  }

  return base;
}

function validateSettings(input) {
  const next = mergeSettings(input);
  if (next.forms.recipientEmail && !isEmail(next.forms.recipientEmail)) {
    const error = new Error('Enter a valid recipient email address.');
    error.statusCode = 400;
    throw error;
  }

  for (const [key, value] of Object.entries(next.content)) {
    if (!value) {
      const error = new Error(`"${key}" cannot be empty.`);
      error.statusCode = 400;
      throw error;
    }
  }

  return next;
}

function hasKvStore() {
  return Boolean(process.env.KV_REST_API_URL && process.env.KV_REST_API_TOKEN);
}

function fileStorePath() {
  if (process.env.CMS_STORE_PATH) return process.env.CMS_STORE_PATH;
  if (process.env.VERCEL) return path.join('/tmp', 'nexus-cms-settings.json');
  return path.join(process.cwd(), '.data', 'nexus-cms-settings.json');
}

function storeInfo() {
  if (hasKvStore()) {
    return {
      provider: 'vercel-kv',
      persistent: true,
      note: 'Settings are stored in Vercel KV.'
    };
  }

  return {
    provider: 'file',
    persistent: !process.env.VERCEL,
    note: process.env.VERCEL
      ? 'File fallback is temporary on Vercel. Add KV_REST_API_URL and KV_REST_API_TOKEN for durable production edits.'
      : `Settings are stored at ${fileStorePath()}.`
  };
}

async function readFromKv() {
  const response = await fetch(`${process.env.KV_REST_API_URL}/get/${encodeURIComponent(STORE_KEY)}`, {
    headers: { Authorization: `Bearer ${process.env.KV_REST_API_TOKEN}` },
    cache: 'no-store'
  });

  if (!response.ok) throw new Error(`KV read failed (${response.status})`);
  const payload = await response.json();
  if (!payload.result) return null;
  return typeof payload.result === 'string' ? JSON.parse(payload.result) : payload.result;
}

async function writeToKv(settings) {
  const response = await fetch(`${process.env.KV_REST_API_URL}/set/${encodeURIComponent(STORE_KEY)}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.KV_REST_API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(settings)
  });

  if (!response.ok) throw new Error(`KV write failed (${response.status})`);
}

async function readFromFile() {
  try {
    const raw = await fs.readFile(fileStorePath(), 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

async function writeToFile(settings) {
  const target = fileStorePath();
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, `${JSON.stringify(settings, null, 2)}\n`, 'utf8');
}

async function getSettings() {
  const stored = hasKvStore() ? await readFromKv() : await readFromFile();
  return mergeSettings(stored);
}

async function saveSettings(input) {
  const next = validateSettings(input);
  if (hasKvStore()) await writeToKv(next);
  else await writeToFile(next);
  return next;
}

module.exports = {
  getSettings,
  saveSettings,
  storeInfo,
  validateSettings
};
