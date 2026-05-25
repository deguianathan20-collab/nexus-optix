const nodemailer = require('nodemailer');

const SMTP_HOST = 'smtp.gmail.com';
const SMTP_PORT = 587;

const stripTags = (v) => String(v ?? '').replace(/<[^>]*>/g, '').trim();
const isEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const body = req.body || {};

  // Honeypot — silently succeed for bots
  if (body.fax_confirm_z) {
    return res.status(200).json({ success: true });
  }

  const firstName   = stripTags(body.firstName);
  const lastName    = stripTags(body.lastName);
  const email       = stripTags(body.email);
  const company     = stripTags(body.company);
  const phone       = stripTags(body.phone);
  const revenue     = stripTags(body.revenue);
  const marketplace = stripTags(body.marketplace);
  const service     = stripTags(body.service);
  const hearAbout   = stripTags(body.hearAbout);
  const message     = stripTags(body.message);

  if (!firstName || !lastName || !email || !company) {
    return res.status(400).json({ success: false, error: 'Required fields missing' });
  }
  if (!isEmail(email)) {
    return res.status(400).json({ success: false, error: 'Invalid email address' });
  }

  const { SMTP_USER, SMTP_PASS, MAIL_TO, MAIL_FROM } = process.env;
  if (!SMTP_USER || !SMTP_PASS || !MAIL_TO || !MAIL_FROM) {
    console.error('Missing SMTP env vars');
    return res.status(500).json({ success: false, error: 'Mail service not configured' });
  }

  const subject = `New Contact Form Submission — ${firstName} ${lastName} (${company})`;
  const ip = req.headers['x-forwarded-for'] || req.headers['x-real-ip'] || 'unknown';
  const submittedAt = new Date().toUTCString();

  const text = [
    'New lead from the Nexus Brand Group website contact form:',
    '',
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    `Name:         ${firstName} ${lastName}`,
    `Email:        ${email}`,
    `Company:      ${company}`,
    `Phone:        ${phone || '—'}`,
    `Revenue:      ${revenue || '—'}`,
    `Marketplace:  ${marketplace || '—'}`,
    `Service:      ${service || '—'}`,
    `Heard About:  ${hearAbout || '—'}`,
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    '',
    'Message:',
    message || '(No message provided)',
    '',
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    `Submitted: ${submittedAt}`,
    `IP: ${ip}`,
  ].join('\n');

  try {
    const transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: false,
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    });

    await transporter.sendMail({
      from: `Nexus Website <${MAIL_FROM}>`,
      to: MAIL_TO,
      replyTo: `${firstName} ${lastName} <${email}>`,
      subject,
      text,
    });

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('Mail send failed:', err.message);
    return res.status(500).json({ success: false, error: 'Mail delivery failed', detail: err.message });
  }
};
