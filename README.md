# Expense Lens

A runnable mobile-first personal + Well On family expense dashboard built from Derek’s PRD. The existing Google Forms and Sheets remain unchanged.

## Try it immediately

Open **expense-lens-preview.html** in a browser. It is a self-contained interactive demo, not a live Google Sheets connection. Demo values are fictional and anchored to 10 September 2026. Scope switching, comparison drill-down, search, date jump, payer filters, insights and modals work offline. The Personal Add expense link opens the real form already supplied; no form is submitted by the app. The Family form has not yet been supplied.

## Run the web app locally — no package installation required

Node.js **22 or newer** is required. Prebuilt production assets are included.

```sh
cd expense-lens
node server/index.mjs
```

Open http://localhost:3000. The default is explicitly labelled demo mode. The server uses Node built-ins only. The frontend is already bundled into `dist/`.

## What is built

- Responsive Overview / Activity / Insights with desktop sidebar and mobile bottom navigation.
- Combined / Personal / Family scopes, plus payer filter within Family.
- Monthly category comparison, current-month aligned dates, full-month switch, previous-month-only categories, zero/negative-safe percentage labels.
- Personal + Family totals without double-counting; Family paid by Derek stays Family.
- Category bar drill-down reconciles to contributing records from the same snapshot.
- Chronological daily feed with neutral gaps, search in category/remarks, category filter, date jump, earlier-day loading and expense detail dialog.
- Deterministic category-change, large-positive-entry and similar-entry signals, with baseline dates and source records.
- Signed integer-cents calculations. No automatic removal of similar-looking records.
- Refresh on open/focus and every 30 seconds while visible; manual refresh and client failure backoff.
- Separate source freshness, last-good snapshots, invalid-row diagnostics, and incomplete-data warnings. Unreliable data pauses insights.
- Server-side Google OAuth with PKCE, nonce, signed HttpOnly session, verified Google ID-token signatures and approved-email check.
- Read-only Sheets API service-account reader for both sources, header mapping, date parsing, schema validation and per-source cache.
- Light and dark modes, reduced-motion support, focus indicators and semantic dialogs.

## Live setup

Live data is **not connected or verified yet**. Do not set live mode until the configuration is complete. Never paste secrets into chat, the HTML preview, or source control.

### 1. Prepare source details

Provide both spreadsheet IDs and exact response tab names. The Personal sheet requires:

`Timestamp | Category | Amount | Remarks`

The Family sheet requires:

`Timestamp | Category | Amount | Pay by | Remarks`

Rows may be sorted/reordered. Configure ranges including the header row and all response rows, excluding totals/helper sections. Example: `'Form Responses 1'!A:D` and `'Form Responses 1'!A:E`. Do not cap the range at today’s final row.

Confirm both currencies are HKD. This build intentionally refuses live startup without `CURRENCY_CONFIRMED=HKD`; there is no FX conversion. Confirm negative-entry meaning before treating insight labels as authoritative.

The reader expects both source spreadsheet timezones to be **Asia/Hong_Kong** and will report a source configuration error otherwise. Verify actual settings; do not change an established source timezone without reviewing its historical interpretation. The API uses unformatted values / Google serial dates. Text dates must be `DD/MM/YYYY HH:mm:ss` (time optional). Ambiguous or invalid values are rejected visibly.

### 2. Configure Google Cloud

1. Create/select a Google Cloud project and enable the Google Sheets API.
2. Create a service account for read-only spreadsheet access.
3. Share each specific spreadsheet with the service-account email as **Viewer**. Keep the sheets private; do not publish to the web.
4. Obtain the service account email and private key using Google’s secure credential flow. Store them locally or in the hosting provider’s secret manager only. Protect/delete downloaded key copies when no longer needed; rotate a key if exposed.
5. Configure the OAuth consent screen for the app with `openid` and `email`. If in testing mode, add Derek’s account as a test user.
6. Create an OAuth client of type **Web application**. Set the redirect URI exactly to `http://localhost:3000/auth/callback` for local testing, and `https://YOUR-DOMAIN/auth/callback` for production. Store the client ID/secret securely.

The sign-in identity and service-account spreadsheet access serve different purposes: OAuth approves the user; the service account reads only the shared sheets.

### 3. Configure environment

```sh
cp .env.example .env
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Use the generated random value as `SESSION_SECRET`. Fill all required variables in `.env` (or hosting environment settings):

- `APP_MODE=live`
- `APP_ORIGIN=http://localhost:3000` locally, HTTPS origin in production; no trailing slash.
- `CURRENCY_CONFIRMED=HKD`
- `ALLOWED_EMAIL=derekwtwong@gmail.com`
- `SESSION_SECRET`
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PRIVATE_KEY`
- `PERSONAL_SPREADSHEET_ID`, `FAMILY_SPREADSHEET_ID`
- `PERSONAL_RANGE`, `FAMILY_RANGE`
- `PERSONAL_FORM_URL`, `FAMILY_FORM_URL`

For the private key, use a quoted value with escaped `\n` newlines, or a multiline secret in your host’s secret manager. The server converts escaped newlines. The example contains no actual credentials.

Optional `CATEGORY_MAP_JSON` maps original labels into agreed reporting categories, separately for each source. Default is no mapping:

```json
{"Personal":{},"Family":{}}
```

Do not guess full category labels from truncated screenshots. Original labels remain available for details and insight baselines.

Restart the server after editing environment settings. Live mode never silently falls back to demo data.

### 4. Validate before relying on totals

- Complete Google sign-in with Derek’s approved account.
- Confirm both sources show a successful read and no unexpected rejected rows.
- Reconcile selected month totals with independent sheet sums including negative entries.
- Submit a test expense through your normal form workflow, then return and refresh. Remove/correct any test entry in the source sheet yourself.
- Confirm Family paid by Derek is included exactly once in Combined and not in Personal.
- Check historical date interpretation, category mappings and signed adjustments.
- Simulate loss of one source’s read permission and confirm the app warns rather than showing a partial total as complete. Restore access afterwards.

## Deploy

This is a React/TypeScript client with a small Node HTTP server. Deploy to a host that runs a persistent Node service/container (e.g. a standard Docker-capable host). Use `node server/index.mjs` as the start command and `/health` as a health endpoint. Set environment secrets in the host dashboard and place it behind HTTPS. Register its exact callback URI in Google Cloud.

A Dockerfile is included and uses the prebuilt assets:

```sh
docker build -t expense-lens .
docker run --rm -p 3000:3000 --env-file .env expense-lens
```

Do not upload the live build to a static-only host: OAuth and private Google Sheets reads require the server. The standalone HTML is a demo only. The app has not been deployed to a public URL as part of this delivery.

## Source / development

```
src/App.tsx        React/TypeScript UI
src/style.css      Responsive light/dark UI
shared/model.mjs   Pure calculation, normalization and insight logic + fictional fixtures
server/index.mjs   Private OAuth/session, Sheets API, snapshots and static asset server
scripts/build.mjs  esbuild production + standalone demo build
tests/            Domain and server-boundary tests
dist/             Prebuilt runnable client assets
```

To modify/rebuild, install the development dependencies on a network-enabled machine:

```sh
npm install
npm run build
npm test
npm start
```

The build uses React + TypeScript with esbuild, custom accessible CSS and native comparison bars instead of the PRD’s proposed Next.js/shadcn/Recharts/TanStack stack. The PRD’s interaction and data rules are retained. This avoids unnecessary runtime dependencies and lets the included build run immediately. Server/shared modules are JavaScript ES modules. The TypeScript source is transpiled; a full type-check with React type packages was not available in the offline build environment.

## Testing / limitations

Automated domain tests cover signed cents, explicit dates, Google serial dates, header mapping, invalid records, unknown payers, duplicate retention, source reconciliation, aligned/full comparisons, leap years and history-gated signals. Browser checks cover all three screens, payer-filter reset, chart drill-down, search/empty states, earlier-day loading, dialogs, dark mode and 360px overflow. Live Google OAuth completion and actual Sheets reads still require credentials and have **not** been end-to-end verified.

Included `scripts/qa.mjs` is the local browser QA harness used during development; it additionally needs Playwright and a Chromium binary. It is not needed to run the app.

Known scope limits: no hosting deployment, no source editing, no reimbursement calculations, no budget/group configuration UI, no Paid by me shortcut, no offline record persistence or PWA install flow. Insights use starting rule thresholds and should be tuned against real history. Source history completeness is conservatively inferred from the earliest source record; the app cannot prove that an unrecorded month was complete. Pagination increases the day window rather than full DOM virtualization. Very large histories may need further optimization.

Source snapshots are in-memory, not a second database. Cache revalidation age is 20 seconds, manual refresh has a 5-second minimum, and concurrent source reads are deduplicated per process. A server restart loses last-good snapshots; cold failures show unavailable status rather than invented history. This is an initial working build, not a claim of a production security audit.
