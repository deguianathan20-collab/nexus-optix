# Deployment — Nexus Brand Group on Vercel

## What's in this repo now

```
public_html-40/
├── api/
│   └── contact.js          ← Vercel serverless contact-form handler
├── Nexus static/            ← static HTML (served as site root)
│   ├── nexus-contact.html  ← wired to /api/contact (real fetch, honeypot active)
│   └── ... (32 other pages)
├── package.json             ← declares nodemailer dependency
├── vercel.json              ← cleanUrls + outputDirectory + redirects
└── .gitignore
```

## One-time setup

### 1. Install dependency
```bash
npm install
```

### 2. Add environment variables in Vercel
In the Vercel dashboard → your project → **Settings → Environment Variables**, add (scope: Production + Preview + Development):

| Name | Value |
|------|-------|
| `SMTP_USER` | `hello@nexusbrandgroup.com` |
| `SMTP_PASS` | *(the Google App Password — see note below)* |
| `MAIL_TO` | `deguianathan20@gmail.com` &nbsp; ⚠️ **TEMPORARY — flip back to `hello@nexusbrandgroup.com` before launch** |
| `MAIL_FROM` | `hello@nexusbrandgroup.com` |

> Why `MAIL_TO` is temporarily redirected: routes test submissions to a dev inbox while you preview-deploy and verify, so the real business inbox doesn't get test data. `SMTP_USER`/`SMTP_PASS`/`MAIL_FROM` stay on the Workspace account — those are what authenticates with Gmail SMTP and what the recipient sees as the From address. Only the delivery destination changes.

> The current App Password value lives in the deleted `send-contact.php` in git history. To get it: `git show <earliest-commit>:send-contact.php | findstr SMTP_PASS` — copy the 16-char value (spaces are fine).
>
> ⚠️ Because that App Password sits in git history, **anyone with read access to this repo can recover it.** If the repo is public — or might become public — rotate at https://myaccount.google.com/apppasswords.

### 3. Connect repo & deploy
- Push the branch to GitHub.
- In Vercel → **Add New → Project** → import the repo.
- Vercel auto-detects `vercel.json`. No build command needed.
- First deploy lands on a `*.vercel.app` preview URL.

## Local testing

```bash
npm install -g vercel
vercel dev
```

This serves the static site AND runs the serverless function locally at `http://localhost:3000`. You'll need to create a `.env.local` at the repo root (gitignored) with the four env vars above for the form to actually deliver mail.

`.env.local` template (replace `<APP_PASSWORD>` with the value from git history):
```
SMTP_USER=hello@nexusbrandgroup.com
SMTP_PASS=<APP_PASSWORD>
MAIL_TO=hello@nexusbrandgroup.com
MAIL_FROM=hello@nexusbrandgroup.com
```

## Verification checklist (run on preview URL before promoting to production)

- [ ] `/` loads — homepage renders
- [ ] `/nexus-contact` loads — form visible
- [ ] Submit form with real test data → check `hello@nexusbrandgroup.com` inbox → email arrives with all fields populated, Reply-To = submitter
- [ ] Submit form with the honeypot field `fax_confirm_z` filled (use DevTools to set value, then submit) → response shows success but NO email arrives
- [ ] Submit form with missing First Name → response shows 400 "Required fields missing", browser alerts
- [ ] Submit form with `email=not-an-email` → response shows 400 "Invalid email address"
- [ ] Click every nav link on every page → no 404s
- [ ] `/contact-form-shows.html` redirects to `/contact-form-shows` (cleanUrls redirect works)

## Pre-launch checklist (do these BEFORE pointing the real domain)

- [ ] In Vercel env vars, change `MAIL_TO` from `deguianathan20@gmail.com` (temp dev inbox) → `hello@nexusbrandgroup.com`.
- [ ] Trigger a redeploy after the env var change (env var edits don't auto-redeploy).
- [ ] Submit one real test form on the production URL → confirm it lands in `hello@nexusbrandgroup.com`, not your personal inbox.
- [ ] Fill in `[DATE]`, `[STATE]`, `[COUNTY/STATE]` placeholders in `nexus-privacy-policy.html` and `nexus-terms-of-service.html`.
- [ ] (Recommended) have a lawyer review the legal stubs.

## Domain cutover (when client grants DNS access)

1. In Vercel → project → **Settings → Domains** → add `nexusbrandgroup.com` and `www.nexusbrandgroup.com`. Vercel will show the exact records you need.
2. At the registrar/DNS host:
   - Add the A record + CNAME Vercel provides.
   - **Do NOT touch MX records.** They must continue pointing to Google Workspace, or the form's SMTP send (and your inbox) will break.
3. Wait for SSL provisioning (~5 min). Confirm `https://nexusbrandgroup.com` loads.
4. Production is live.

## Phase 2 complete — what shipped

- 17 un-prefixed duplicate pages deleted; replaced by 301 redirects in `vercel.json`.
- `nexus-privacy-policy.html` + `nexus-terms-of-service.html` stubs added (clearly marked as needing legal review).
- `sitemap.xml` (16 canonical URLs) + `robots.txt` added at site root.
- All canonical, `og:url`, and JSON-LD breadcrumb URLs updated to match the actual served path (was pointing at the deleted slugs).
- All `?v5.1773332954297` cache-busting query strings stripped from every link.
- Broken `nexus-redesign.html` "Home" link (which referenced a file that doesn't exist) rewritten to `index.html` across all pages.
- `nexus-tools-portal.html` and `nexus-tools-landing.html` got the missing description + canonical + `noindex` (portal) / `index` (landing).
- Cache-control headers in `vercel.json` narrowed from `/(.*)` to only `*.html` + `/` — static assets can now actually cache.

## Remaining nice-to-haves (not blockers)

- `thank-you.html` is unclear in purpose (uses homepage title, has no `nexus-*` pair) — left in place but `Disallow`-ed in `robots.txt`. Confirm with stakeholder whether it's still needed.
- BreadcrumbList structured data still has page-specific "name" fields referencing old labels (e.g., "About Us" on `nexus-about`) — Google reads the canonical URL fine, so this is cosmetic.
- Per-page inline `<style>` blocks duplicate ~5KB of CSS across every page (~100KB total). Worth extracting later, not urgent.
- Replace the legal `[DATE]`, `[STATE]`, `[COUNTY/STATE]` placeholders before launch.
