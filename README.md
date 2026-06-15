# Switchboard

A tiny single-tenant business phone line built on **SignalWire**. 
You pick a phone number, point it at your real phone, and inbound calls are 
forwarded through SignalWire. That's the whole product — it's a clean base 
to build on.

- **Ruby on Rails 7.2** + **PostgreSQL**
- Fully containerized with **Docker Compose**
- SignalWire integration is built with the **native APIs** — SWML for call control
  and the Relay REST API for number management (not the Twilio Compatibility API)
- Inbound calls are handled by a live **SWML webhook** the app serves
- A bundled **Cloudflare quick tunnel** gives SignalWire a public URL to reach
  that webhook — free, no account or token required

---

## Prerequisites

- **Docker** + **Docker Compose** (Debian/Ubuntu: `sudo apt install docker.io docker-compose-v2`)
- A **SignalWire** Project ID and API token — we send these via a one-time link
  (the Space URL is already filled in for you)
- A **phone** you can receive forwarded calls on

## Quick start

```bash
cp .env.example .env        # paste the project ID + token from the one-time link
docker compose up --build
```

Then open **http://localhost:3000**.

> ⚠️ **Local use only.** This stack runs Rails in **development mode** (verbose
> error pages, code reloading, `web-console`) and the bundled Cloudflare quick
> tunnel gives it a **public URL**. That combination is great for testing a real
> inbound call, but it is **not safe to leave running as a public deployment** —
> an unhandled error would render a full backtrace to anyone who reaches the
> tunnel. For anything beyond local testing, run in `RAILS_ENV=production` behind
> your own HTTPS endpoint and set `SECRET_KEY_BASE` + `APP_HOSTS` (see
> [Configuration](#configuration)).

1. Sign in with the dashboard password (`DASHBOARD_PASSWORD`, default `changeme`).
2. **Onboarding** runs the first time:
   - search for an available number by area code and buy one,
   - enter the phone number to forward calls to.
3. You land on the **dashboard**. Call your new SignalWire number — it should ring
   your forwarding phone.

That's it. To change where calls go, edit the forwarding number on the dashboard
(takes effect instantly — no SignalWire call needed).

## How it works

```
                 ┌─────────────────────── docker compose ────────────────────────┐
  inbound call   │                                                               │
  ──────────────▶  SignalWire DID                                                │
                 │      │  (call_handler: relay_script, call_relay_script_url)   │
                 │      ▼                                                        │
                 │ cloudflared quick tunnel  ──▶  Rails web (Puma)  ──▶  Postgres│
                 │   *.trycloudflare.com           POST /calls/inbound           │
                 │                                 returns SWML  ────────┐       │
                 └───────────────────────────────────────────────────────┼───────┘
                                                                         ▼
                                                          { connect: { to: <forwarding #> } }
                                                                         │
                                                                         ▼
                                                                  your phone rings
```

- **Provisioning** (onboarding): the app calls the SignalWire Relay REST API to
  search (`GET /api/relay/rest/phone_numbers/search`), purchase
  (`POST /api/relay/rest/phone_numbers`), and point the number at our webhook
  (`PUT …/{id}` with `call_handler: "relay_script"`).
- **Call handling**: on each call SignalWire POSTs to `/calls/inbound`; the app
  returns an SWML `connect` document forwarding to the current destination. The
  webhook is public (SignalWire isn't logged in), so it's authenticated by a
  per-install secret token baked into the webhook URL the app configures on the
  number — unauthenticated requests get a `403`. To rotate the token, call
  `Account.instance.regenerate_webhook_token` then re-sync (the **Re-sync**
  button on the Admin page or `rake signalwire:sync_webhook`).
- **Public URL**: `cloudflared` prints its random `*.trycloudflare.com` URL to a
  shared log file; the app reads it (`app/services/public_url.rb`) and keeps the
  SignalWire number pointed at it (`app/services/webhook_sync.rb`). Because quick
  tunnels get a new URL on each restart, the dashboard re-syncs automatically on
  load; the **Admin** page shows the sync status and a manual "Re-sync" button.

## Project layout

```
app/
  controllers/
    sessions_controller.rb      # single-password login
    onboarding_controller.rb    # first-run wizard: search → buy → set forwarding
    dashboard_controller.rb     # customer view; silently re-syncs the webhook on load
    forwarding_controller.rb    # change the forwarding number
    phone_numbers_controller.rb # release the number / start over
    admin_controller.rb         # admin view: inbound-route sync status
    webhook_controller.rb       # manual webhook re-sync (Admin page)
    calls_controller.rb         # SignalWire inbound-call webhook → SWML
  models/
    account.rb                  # singleton settings (forwarding #, onboarding state)
    phone_number.rb             # the purchased SignalWire DID
    call_log.rb                 # inbound call history
  services/
    signalwire_client.rb        # native Relay REST API wrapper
    swml.rb                     # builds SWML documents
    public_url.rb               # resolves the cloudflared / PUBLIC_URL base URL
    webhook_sync.rb             # reconciles the number's webhook with the public URL
lib/tasks/signalwire.rake       # rake signalwire:sync_webhook
docker-compose.yml              # db + web + cloudflared
```

## Running tests

```bash
docker compose run --rm web bin/rails test
```

## Configuration

All config is environment variables (see `.env.example`):

| Variable | Purpose |
| --- | --- |
| `SIGNALWIRE_PROJECT_ID` / `SIGNALWIRE_API_TOKEN` / `SIGNALWIRE_SPACE_URL` | Native REST API auth |
| `DASHBOARD_PASSWORD` | Dashboard login (default `changeme`) |
| `PUBLIC_URL` | Override the tunnel with your own stable URL (optional) |
| `POSTGRES_*` | Database connection (compose defaults are fine) |

## Troubleshooting

- **Dashboard says "No public URL yet"** — give `cloudflared` a few seconds after
  boot, then reload. Check it's healthy: `docker compose logs cloudflared`.
- **Calls don't forward** — open the **Admin** page; confirm it shows **In sync**
  and click **Re-sync** if not. Verify the number rings at all in your SignalWire
  Space.
- **"Blocked host" error** — already handled for `*.trycloudflare.com` in
  development. If you set a custom `PUBLIC_URL`, it's allowlisted automatically.
- **Can't release a number** — SignalWire holds freshly purchased numbers for 14
  days. The app removes it locally and tells you; release it later from the Space.

See [`CANDIDATE.md`](CANDIDATE.md) for the exercise brief.
