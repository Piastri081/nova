# Nova

Nova is a native SwiftUI iOS app for browsing and streaming **public-domain and Creative Commons films** from the Internet Archive. It is a complete, working Netflix-style client — sign in, pick a profile, browse rows, search, save a list, resume playback, and add Home/Lock Screen widgets — with a Cloudflare backend that keeps accounts in sync across devices.

Nova is **not** affiliated with Netflix and does not host, upload, or index unauthorized content. It streams only titles that are publicly available on the Internet Archive, and each title links back to its source/license page.

## What's included

- Native SwiftUI app (no web view, no React Native)
- Passwordless sign-in with 6-digit **email** or **SMS** codes
- Up to **5 profiles per account**, each with its own My List, Continue Watching, and playback progress
- Optional 4-digit profile PIN with server-side hashing and lockout
- Kids profiles with server-side catalog filtering
- Continue Watching row with resume playback
- Cloud-synced account, profiles, progress, and watchlist via Cloudflare Workers + D1
- **Liquid Glass** UI on iOS 26+, with an automatic material fallback on older iOS versions and when built with Xcode 16
- WidgetKit widgets for the **Home Screen** and **Lock Screen**
- GitHub Actions workflows for an unsigned IPA and a GitHub Pages download site

## Repository layout

```
App/                 SwiftUI app target
  Resources/         Asset catalog and app icon
  Sources/           Screens, auth, API client, theme
Widgets/             WidgetKit extension
Shared/              Models, shared store, poster cache (used by both targets)
Backend/             Cloudflare Worker, D1 schema, curated catalog
docs/                Static GitHub Pages release/download page
scripts/             Local IPA build helper
project.yml          XcodeGen project definition
```

## Use the hosted app

Download the latest `Nova.ipa` from **Releases**. The official build is preconfigured for the hosted Nova cloud, so users do not deploy anything:

1. Install the IPA with AltStore, Sideloadly, or Xcode.
2. Open Nova and enter an email address or phone number.
3. Enter the 6-digit code and pick a profile.

Accounts, profiles, My List, and Continue Watching are stored in the hosted Cloudflare backend, so signing in on another device restores everything.

## Build from source

Requirements:

- macOS with Xcode 16 or newer (Xcode 26+ enables native Liquid Glass)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
xcodegen generate
open Nova.xcodeproj
```

The app reads its API URL from the `NOVA_API_BASE_URL` build setting (surfaced as `API_BASE_URL` in the Info.plist). To point a local build at your own Worker:

```bash
NOVA_API_BASE_URL="https://nova-api.your-name.workers.dev" ./scripts/build-ipa.sh
```

You can also change the server at runtime in **Profile → Server** or **Sign In → Server**.

### Build an unsigned IPA

```bash
chmod +x scripts/build-ipa.sh
./scripts/build-ipa.sh
```

The script produces `Nova.ipa` in the repository root. The same build runs in GitHub Actions on every push and tag.

## Deploy the hosted backend (maintainers)

The public deployment is a single Cloudflare Worker plus D1 (and optional KV). See [`Backend/README.md`](Backend/README.md) for the full walkthrough. The short version:

```bash
cd Backend
npm install
npx wrangler login
npx wrangler d1 create nova
# copy the database_id into wrangler.toml
npx wrangler kv namespace create CACHE
# copy the KV id into wrangler.toml
npx wrangler d1 execute nova --file=./schema.sql --remote
npx wrangler secret put CODE_PEPPER
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put EMAIL_FROM
# or use Brevo instead of Resend
npx wrangler secret put BREVO_API_KEY
# optional SMS
npx wrangler secret put TWILIO_ACCOUNT_SID
npx wrangler secret put TWILIO_AUTH_TOKEN
npx wrangler secret put TWILIO_FROM
npx wrangler deploy
```

Then set the repository variable **`NOVA_API_BASE_URL`** to the deployed Worker URL (for example `https://nova-api.your-name.workers.dev`). The iOS workflow injects it into every release build. Until it is set, builds use the placeholder URL and the app shows a server warning.

For local development, copy `.dev.vars.example` to `.dev.vars` and keep `DEV_RETURN_CODE=true`. In dev mode the API returns the 6-digit code in the response and the app displays it on the verification screen. Never enable that in production.

## GitHub setup

1. Create a new repository and push this folder.
2. Optionally set `NOVA_REPO` in `docs/config.js`. On GitHub Pages the links auto-detect `owner/repo`; a custom domain needs the explicit value.
3. Enable **Settings → Pages → Source: GitHub Actions**.
4. Add repository **variables**:
   - `NOVA_API_BASE_URL` — the public Worker URL used by release builds
5. Add repository **secrets** for backend deployment:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
6. Push a tag such as `v1.0.0`. The `iOS` workflow builds `Nova.ipa` and attaches it to the GitHub Release. The Pages site links to the latest release.

## Signing and sideloading

The CI artifact is **unsigned**. iOS will not install it directly. Use AltStore, Sideloadly, or Xcode with your own Apple ID/team:

- Widgets and App Groups require a provisioning profile that includes the App Group `group.com.example.nova`.
- If you fork this project, change the bundle IDs and App Group in `project.yml`, `App/Info.plist`, `Widgets/Info.plist`, and the entitlements files.
- Free Apple IDs expire after 7 days; a paid developer account gives longer-lived builds.

## Configuration

| Setting | Where |
| --- | --- |
| Hosted API URL | Repository variable `NOVA_API_BASE_URL`, or `NOVA_API_BASE_URL` build setting |
| Runtime override | In-app **Profile → Server** / **Sign In → Server** |
| Bundle IDs / App Group | `project.yml`, plists, entitlements |
| Curated catalog | `Backend/src/curated.ts` |
| D1 schema | `Backend/schema.sql` |

## API overview

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/v1/auth/request-code` | Send a 6-digit email/SMS code |
| `POST` | `/v1/auth/verify` | Verify code, create account/profile, return session token |
| `POST` | `/v1/auth/logout` | Revoke the current session |
| `GET/PATCH/DELETE` | `/v1/me` | Read, rename, or permanently delete the account |
| `GET` | `/v1/session` | Restore account + profiles on a new device |
| `GET/POST` | `/v1/profiles` | List/create profiles |
| `PATCH/DELETE` | `/v1/profiles/:id` | Edit/delete a profile |
| `POST` | `/v1/profiles/:id/unlock` | Verify a profile PIN |
| `GET` | `/v1/catalog/home` | Home rows + Continue Watching for the active profile |
| `GET` | `/v1/catalog/public` | Public catalog (used by widgets) |
| `GET` | `/v1/catalog/search?q=` | Search, filtered for kids profiles |
| `GET` | `/v1/titles/:id` | Title detail |
| `GET/PUT` | `/v1/progress` | Read/update playback progress per profile |
| `GET/POST/DELETE` | `/v1/watchlist` | Per-profile My List |

Authenticated requests use `Authorization: Bearer <token>`. Profile-scoped requests add `X-Nova-Profile: <profile id>`.

## Security notes

- Login codes and profile PINs are stored as salted SHA-256 hashes, never plaintext.
- Session tokens are random 256-bit values; only their hashes are stored in D1.
- Codes expire after 10 minutes, are single-use, and are rate-limited per identifier and IP.
- PIN attempts are rate-limited and lock the profile for 5 minutes after 5 failures.
- Profile PINs are a convenience lock for shared devices, not a substitute for device security.
- Use HTTPS for the Worker; the app accepts `http://` only for local development.

## Legal

Nova does not host media. It links to items on the Internet Archive and shows a source/license link on every detail page. Public-domain status can vary by country. Verify that you are allowed to stream a title in your jurisdiction. Do not add scrapers or links to unauthorized streaming sites.

## License

The application code is provided under the MIT License. Catalog metadata belongs to its respective sources; each film retains its original license.
