# Switchboard — guide for AI agents

A single-tenant business phone line on SignalWire: it forwards a SignalWire
number to a real phone. See `README.md` for the full file map and architecture
diagram, and `CANDIDATE.md` for the task brief. This file is just the few things
worth knowing before you change code.

## Run & test — your feedback loop

```bash
docker compose up --build                      # app on http://localhost:3000
docker compose run --rm web bin/rails test     # the test suite
docker compose run --rm web bin/rubocop        # lint (omakase)
```

- Sign in with `DASHBOARD_PASSWORD` (default `changeme`).
- App code is bind-mounted — edits reload live. Rebuild only when `Gemfile` changes.
- **The tests stub SignalWire and need no credentials.** You can build and verify
  almost everything against `bin/rails test` without the live project; only
  placing a real phone call needs the provided credentials and a phone.

## How this codebase talks to SignalWire

It's built on SignalWire's **native** APIs:
- **SWML** for call control — built in `app/services/swml.rb`.
- **Relay REST** for number management — in `app/services/signalwire_client.rb`.

It does **not** use the Twilio Compatibility API (cXML / LaML / TwiML,
`/api/laml/...`, `IncomingPhoneNumbers`/`AvailablePhoneNumbers`, `twilio-ruby`).
Most telephony examples on the web default to Twilio, so they won't match what's
here — translate them to SWML/Relay REST. You can reach for the Compatibility API
if you have a reason to, but mixing the two can be challenging.

## Reference docs — fetch these instead of guessing

Every page under `signalwire.com/docs` has a Markdown twin (append `.md` to the
URL), and each section has an `llms.txt` index listing them. **Prefer these over
web search**, which tends to surface the Twilio API rather than the native one
used here. The pages below are the native SWML / Relay REST docs this codebase
actually uses.

- **Doc indexes:** https://signalwire.com/docs/llms.txt — top level;
  https://signalwire.com/docs/swml/llms.txt — SWML;
  https://signalwire.com/docs/apis/llms.txt — REST APIs.
- **SWML call control:** https://signalwire.com/docs/swml/reference/calling.md —
  document structure, the inbound webhook payload, variable expansion, and every
  method. Per-method pages live at `…/swml/reference/calling/<method>.md`, e.g.
  `connect.md`, `play.md`, `prompt.md`, `record.md`, `record-call.md`, `switch.md`,
  `answer.md`, `hangup.md`.
- **Relay REST — number management** (all `/api/relay/rest/phone_numbers`), under
  `https://signalwire.com/docs/apis/rest/phone-numbers/<page>.md`:
  `search-available-phone-numbers`, `purchase-phone-number`, `list-phone-numbers`,
  `release-phone-number`, and `update-phone-number` (the inbound handler:
  `call_handler: relay_script` + `call_relay_script_url`).

## How an inbound call flows

`SignalWire POST /calls/inbound` → `CallsController#inbound` → `Swml.*` returns an
SWML JSON document → SignalWire acts on it; a `CallLog` row is written.

SWML documents are plain JSON. Build them in `app/services/swml.rb` and unit-test
them in `test/services/swml_test.rb` (pure, no credentials). Number provisioning
and routing live in `app/services/signalwire_client.rb`. App-wide settings are a
single row: `Account.instance`.

## Gotchas that will bite you

- **The webhook URL is the single source of truth — don't hand-roll it.** The
  `/calls/inbound` endpoint is public and CSRF-exempt, authed by a secret token
  in the query string (`Account#webhook_token`, checked in
  `CallsController#verify_webhook_token`). Use `Account#inbound_webhook_url` to
  build the tokened URL; `WebhookSync` is what pushes it to SignalWire.
- **The public URL is ephemeral.** It comes from a cloudflared quick tunnel that
  gets a new `*.trycloudflare.com` hostname on every restart. `WebhookSync`
  reconciles the number's configured URL (silently on dashboard load, via the
  "Re-sync" button on the Admin page, and `rake signalwire:sync_webhook`). Don't
  fight the changing URL — rely on that reconciliation.
