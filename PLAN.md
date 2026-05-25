# Nexus Brand Group — Implementation Plan

**Goal:** ship the existing 33-page static site live on Vercel with a working contact form and the SEO/structural basics in place.

**Out of scope (deferred):** CMS, tools/Optix portal backend, newsletter, gated downloads.

---

## Status

- ✅ **Phase 1 complete** — `api/contact.js` built, `nexus-contact.html` wired up, PHP/debug artifacts deleted.
- ✅ **Phase 2 complete** — Duplicates removed, legal stubs drafted, sitemap/robots created, broken `nexus-redesign.html` nav fixed, canonical URLs corrected, OG/breadcrumb URLs aligned, cache-busters stripped.
- ⏸️ **Phase 3 blocked on DNS access from client.** Preview deploy is unblocked.

---

## Phase 1 — Make the contact form work on Vercel (the actual blocker)

The current form (`contact.html` → `/send-contact.php`) is PHP. Vercel can't run PHP. We rewrite it as a Vercel Function.

### 1.1 Build `api/contact.js` (Node serverless function)
- Mirror `send-contact.php` logic: honeypot, field validation, SMTP send to `hello@nexusbrandgroup.com`.
- Use `nodemailer` for SMTP (avoids the hand-rolled socket code in the PHP).
- Read all credentials from `process.env` (`SMTP_USER`, `SMTP_PASS`, `MAIL_TO`, `MAIL_FROM`).
- Return the same JSON shape (`{success: true}` / `{success: false, error}`) so the client doesn't change.
- Add `package.json` + `package-lock.json` with `nodemailer` dependency.

### 1.2 Update the client
- `contact.html:1279` — change `fetch('/send-contact.php')` → `fetch('/api/contact')`.
- Switch from `FormData` body → JSON body. Vercel auto-parses JSON; multipart needs an extra parser.
- Preserve honeypot field, redirect to `/contact-confirmation` on success.

### 1.3 Rotate & secure credentials (do this FIRST — before any deploy)
- The Gmail App Password `efwm dijo xexw zmup` is currently committed in `send-contact.php:26` and exists in git history. **Revoke it** at https://myaccount.google.com/apppasswords.
- Generate a new App Password, store it ONLY in Vercel's env var UI.
- Delete `send-contact.php`, `contact-debug.log`, `contact-log.txt` from the repo.
- Add `.gitignore` entries for log files and `.env*`.

### 1.4 Fix the Vercel project root
- Site HTML lives in `Nexus static/` subdir, but `vercel.json` is at the repo root. Vercel will deploy the root, which is empty of HTML.
- **Recommended:** move the HTML files from `Nexus static/` up to the repo root. Cleaner long-term; matches Vercel conventions.
- Alternative: add `"outputDirectory": "Nexus static"` to `vercel.json`. Less invasive but the folder name with a space will keep being annoying.

---

## Phase 2 — Polish before launch

### 2.1 Broken / missing links + draft privacy & terms
- Draft `nexus-privacy-policy.html` and `nexus-terms-of-service.html` as basic stubs (matching the existing page template). Standard sections: data collected, how it's used, cookies, contact, governing law, etc. **Flag clearly that this is not legal advice — recommend a lawyer pass before launch.**
- Audit all internal `<a href="*.html">` links. The current `vercel.json` redirects `*.html` → clean URL with a **301**, so every internal click eats a redirect hop. Rewrite hrefs to use clean URLs directly.

### 2.2 Resolve duplicate pages — `nexus-*.html` is canonical
- **Before deleting `contact.html`:** port its `handleSubmit` script + honeypot `<div>` into `nexus-contact.html`, and update the fetch URL to `/api/contact`.
- Delete the un-prefixed duplicates.
- Add `vercel.json` 301 redirects from `/about` → `/nexus-about` (and all other un-prefixed slugs) so any external inbound links don't 404.
- Strip the `?v5.1773332954297`-style cache-busting query strings from internal links in the `nexus-*` pages.

### 2.3 SEO foundation
- Audit each page for unique `<title>` and `<meta name="description">`.
- Add Open Graph tags (`og:title`, `og:description`, `og:image`, `og:url`) per page.
- Add `<link rel="canonical">` per page.
- Create `sitemap.xml` listing the canonical 22-ish pages.
- Create `robots.txt` pointing to the sitemap.
- Add JSON-LD `Organization` schema to homepage at minimum.

### 2.4 Fix the cache headers
Current `vercel.json` sets `no-cache` on `/(.*)` — that includes CSS, fonts, images. For a static site this kills performance.
- Keep `no-cache` only on `*.html`.
- Set long `Cache-Control: public, max-age=31536000, immutable` for static assets.

### 2.5 Quick performance pass
- Check images have width/height attributes (prevents layout shift).
- Convert oversize PNGs/JPGs to WebP where it pays off.
- Verify no inline `<style>` blocks duplicate across every page (if they do, extract to a shared CSS file).

---

## Phase 3 — Deploy & launch

### 3.1 First deploy
- Connect the GitHub repo to Vercel.
- Set env vars in Vercel dashboard (`SMTP_USER`, `SMTP_PASS`, `MAIL_TO`, `MAIL_FROM`).
- Deploy to preview URL first.

### 3.2 Verification on preview
- Submit the contact form with real data → confirm email arrives at `hello@nexusbrandgroup.com`.
- Submit with `fax_confirm_z` filled → confirm honeypot fakes success (no email).
- Submit with missing required fields → confirm 400 + error message shown.
- Click through every nav link on every page → no 404s.
- Run Lighthouse on `/`, `/services`, `/contact` — aim for ≥90 on Performance & SEO.

### 3.3 Custom domain *(blocked on client DNS access)*
- **Blocker:** you need DNS-edit access from the client before this step.
- Once granted: point `nexusbrandgroup.com` apex + `www.` records to Vercel (Vercel will tell you the exact A / CNAME values).
- **Carefully leave MX records on Google Workspace untouched** — the contact form sends through Workspace SMTP, and breaking MX kills both the inbox AND the form.
- Wait for SSL to provision (usually <5 min).
- Promote preview → production.

---

## Order of execution

1. **Rotate the Gmail password** (security — do today, regardless of anything else).
2. Move HTML files to repo root.
3. Build + test `api/contact.js` locally with `vercel dev`.
4. Update `contact.html` to call `/api/contact`.
5. Decide canonical page set + delete duplicates.
6. Create missing `privacy-policy` + `terms-of-service` pages.
7. SEO pass (titles, meta, sitemap, robots, canonical, OG).
8. Fix cache headers + cleanup.
9. Deploy to preview, verify, promote.
10. Point domain.

## Decisions locked in

- **Canonical page set:** `nexus-*.html` (delete the un-prefixed duplicates, or 301 them).
- **Privacy/Terms:** I'll draft basic stubs covering the essentials. Not legal advice — recommend a lawyer review before launch.
- **`hello@nexusbrandgroup.com`:** confirmed monitored.
- **Domain:** registered, **but DNS access is currently with the client.** Need to request access before the final cutover in Phase 3.3. Preview/staging deploys via `*.vercel.app` are unblocked.

## Things this decision surfaced

1. **`nexus-contact.html` is missing the form's JS wiring.** It has the `<form>` HTML and the `onsubmit="handleSubmit(event)"` attribute, but no `handleSubmit` function in the file and no honeypot field. When we consolidate, we port `contact.html`'s `handleSubmit` script + honeypot `<div>` into `nexus-contact.html`. Field names match — no other changes needed.
2. **All the `nexus-*.html` files reference assets/links with cache-busting query strings** like `privacy-policy.html?v5.1773332954297`. Worth stripping these — they don't help on Vercel and they make every link look like junk in shares/analytics.
3. **The contact form footer link** `privacy-policy.html?v5...` → broken (file doesn't exist). Drafting the stubs (Phase 2.1) closes this.

## Phase 3.3 unblocked vs blocked

- **Unblocked:** everything through Phase 3.2 (preview deploy + full verification on `*.vercel.app`). I can hand you a working preview URL with the form delivering real email.
- **Blocked on DNS access:** the final domain switch + SSL on the apex domain. We can do this whenever client grants access — it's a ~10-minute task.
