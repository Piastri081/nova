# Nova backend

Cloudflare Worker + D1 + optional KV. It powers the hosted Nova service and provides passwordless auth, profiles, per-profile progress/watchlist, a curated Internet Archive catalog, and a public endpoint for widgets. You can deploy the same backend to your own Cloudflare account if you prefer.

## Requirements

- Node.js 20+
- A Cloudflare account
- Optional: Resend account for email codes
- Optional: Twilio account for SMS codes

## 1. Install

```bash
npm install
```

## 2. Create D1 and KV

```bash
npx wrangler d1 create nova
npx wrangler kv namespace create CACHE
```

Copy the returned `database_id` and KV `id` into `wrangler.toml`. KV is optional; remove the `[[kv_namespaces]]` block if you do not want caching. The Worker works without KV, just with more Archive.org metadata requests.

## 3. Apply the schema

```bash
npx wrangler d1 execute nova --file=./schema.sql --remote
```

For local development:

```bash
npx wrangler d1 execute nova --file=./schema.sql --local
```

## 4. Set secrets

```bash
npx wrangler secret put CODE_PEPPER          # 32+ random characters
npx wrangler secret put RESEND_API_KEY       # email
npx wrangler secret put EMAIL_FROM           # e.g. Nova <login@your-domain.com>
npx wrangler secret put TWILIO_ACCOUNT_SID   # SMS
npx wrangler secret put TWILIO_AUTH_TOKEN
npx wrangler secret put TWILIO_FROM          # E.164 number you own
```

`CODE_PEPPER` is required and must be at least 16 characters. Email/SMS secrets are only required for the channel you use.

## 5. Local development

```bash
cp .dev.vars.example .dev.vars
npx wrangler dev
```

With `DEV_RETURN_CODE=true`, `POST /v1/auth/request-code` includes `devCode` in the response and the iOS app displays it on the code screen. Never enable this in production.

## 6. Deploy

```bash
npx wrangler deploy
```

Then paste the Worker URL into the app's **Server** field, or set the `NOVA_API_BASE_URL` repository variable so release builds point at it.

## Hosting it for the public

A public deployment needs a few extra guardrails beyond a private instance:

- Keep `DEV_RETURN_CODE=false` and never expose `.dev.vars`.
- Set a long random `CODE_PEPPER` and rotate it only with a planned session reset.
- Configure Resend/Twilio with spending limits and monitor delivery failures.
- The API already limits code requests to 5 per identifier and 25 per IP per 15 minutes, caps login attempts, and locks profile PINs after 5 failures.
- Put the Worker behind a custom domain and keep HTTPS only.
- Review Cloudflare analytics for abuse spikes; add a WAF rule or Turnstile challenge if needed.
- Publish a privacy policy that explains account, profile, and playback data retention.

The included `docs/privacy.html` is a starting point for the hosted service.

## Email and SMS providers

- **Email:** [Resend](https://resend.com). Verify your sending domain and set `EMAIL_FROM` to a sender on that domain.
- **SMS:** [Twilio](https://twilio.com). Set `TWILIO_FROM` to an E.164 number enabled for your account. SMS delivery may require A2P registration depending on your country.

If a channel is not configured and dev mode is off, the API returns `503` with a clear message instead of silently failing.

## Endpoints

See the root [`README.md`](../README.md#api-overview). All profile-scoped routes require `X-Nova-Profile`.

## Catalog

The catalog lives in `src/curated.ts`. Each entry references an Internet Archive item ID. `src/catalog.ts` resolves the best MP4 stream through `archive.org/metadata`, caches results in KV/memory, and builds home rows. To add a title:

1. Find a public-domain or Creative Commons film on archive.org.
2. Copy its item identifier (the part after `/details/`).
3. Add an entry to `CURATED` with title, year, genres, rating, runtime, blurb, tags, and popularity.
4. Redeploy.

Kids profiles only receive titles tagged or genre-classified as family, animation, comedy, adventure, or short.

## Type checking

```bash
npm run typecheck
```

## Schema notes

- `users` — one row per email/phone identifier
- `profiles` — up to 5 per user; `pin_hash` is salted with `CODE_PEPPER`
- `sessions` — hashed bearer tokens with a 30-day expiry
- `login_codes` — hashed, single-use, 10-minute codes with attempt/rate limits
- `progress` — keyed by `(profile_id, title_id)`
- `watchlist` — keyed by `(profile_id, title_id)`

Deleting a profile removes its progress and watchlist rows.
