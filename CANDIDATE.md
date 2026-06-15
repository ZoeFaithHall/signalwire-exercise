# Take-Home Exercise

Welcome, and thanks for your time. This repository is a **small but working
product**: a single-tenant business phone line built on SignalWire.
It forwards calls from a SignalWire phone number to your real phone.

Your job is to **take it somewhere** over roughly **1–2 hours**, guided by the
customer feedback below. We care far more about how you think than how much you
finish.

Afterward you'll have conversations with the team about:
- the technical decisions you made, and
- the product choices and your reasoning.

---

## What works today

- First-run **onboarding**: search SignalWire for an available number, buy one,
  and choose a forwarding destination.
- A **dashboard** to see your number, change the forwarding number, view a log of
  recent calls, and release the number.
- **Call forwarding** end to end: inbound calls hit a live **SWML webhook** the
  app serves and are forwarded to your destination.
- Single shared-password login.

Out of scope today (deliberately): voicemail, SMS, multiple numbers, multiple
users/tenants, business hours, IVR menus. Some of those are great directions to
take it - see below.

## Architecture in one minute

- **Rails 7.2 + PostgreSQL**, all in **Docker Compose** (`db`, `web`,
  `cloudflared`).
- SignalWire integration is built with the **native APIs** (not the Twilio
  Compatibility API / cXML — mixing the two can be tricky):
  - **SWML** for call control (`app/services/swml.rb`, returned by
    `CallsController#inbound`),
  - **Relay REST** for number management (`app/services/signalwire_client.rb`).
- A free **Cloudflare quick tunnel** gives SignalWire a public URL to reach the
  webhook. The URL is ephemeral, so `WebhookSync` reconciles the number's
  configured webhook with the current public URL.

Two flows worth tracing before you start:

1. **Onboarding / provisioning** - `OnboardingController` →
   `SignalwireClient#search_available_numbers` / `#purchase_number` /
   `#set_inbound_webhook`.
2. **An inbound call** - SignalWire `POST /calls/inbound` → `CallsController` →
   `Swml.forward` → call is connected; a `CallLog` row is written.

`README.md` has the full file map, setup steps, and a diagram.

## Getting it running

```bash
cp .env.example .env        # paste the project ID + token from the one-time link
docker compose up --build
# open http://localhost:3000, sign in (DASHBOARD_PASSWORD, default "changeme")
```

Tests:

```bash
docker compose run --rm web bin/rails test
```

Edits to app code are picked up live (the project is bind-mounted). Rebuild only
when you change the `Gemfile`.

## Product feedback

The following feedback has been received by the team from customers.
Use this to help decide what to work on, or come up with your own idea.

1. Sometimes the call hits my phone's voicemail box. I'd
   really like it if I was able to have business voicemails separate from my personal
   voicemails. 

2. I get a lot of calls that ask the same questions. It would
   be nice if I didn't have to answer those same questions all the time.

3. I get my personal and business calls mixed up sometimes.
   Can it be more obvious that the incoming call is for my work and still know who is calling me?

4. Sometimes when I'm away from my desk I don't have a good way to 
   capture the details from my clients over the phone.

5. It's a real pain when I get calls after my day ends. I'm
   currently just sending those calls to voicemail on my mobile phone. I have an
   overnight person that would be better to handle these calls. Can you send it
   to them?

6. I usually get bursts of calls and I want to handle them live. I don't mind if the 
   caller has to wait a minute or two. 

7. I'd prefer if I could take calls from my laptop while I'm in the office.

8. It might be useful to screen my calls before they reach me.



Have a different idea sparked by the product? Pursue it - just be ready to walk
us through the "why."

## What we're looking for

- **Judgment**: sensible scoping, clear trade-offs, knowing what to leave out.
- **Code quality**: readable, consistent with what's here, appropriately tested.
- **Integration sense**: correct, resilient use of the SignalWire APIs.
- **Product thinking**: who is this for, what matters, what you'd do next.

You will **not** be judged on finishing everything, on pixel-perfect UI, or on
guessing some "right" answer. Leave notes (in code comments or a short write-up)
about decisions, assumptions, and what you'd do with more time.

Use whatever tools you'd normally reach for, AI assistants included - what we're
evaluating is your thinking and *why* you made the decisions you made, not whether
you typed every line yourself.

## Submitting your work

The **1-2 hours is coding time** - getting Docker up, provisioning a number, and
placing a test call is setup on top of that, so don't let the clock scare you.

When you're happy with where it landed (or your time's up):

1. **Capture your reasoning** in a short `NOTES.md`: decisions, assumptions,
   trade-offs, and what you'd do next. A few paragraphs is plenty.
2. **Send it back.** Zip up the project directory and share the archive with us.

No need to deploy anything or tie off every loose end you've noted - bring those
to the follow-up conversations, where the team walks through your code and product
choices with you.

## Notes & gotchas

- The cloudflared quick-tunnel URL changes on restart; the dashboard auto-syncs
  on load, and the **Admin** page shows the sync status with a manual **Re-sync**
  button (`rake signalwire:sync_webhook` does the same from the CLI).
- The SignalWire project we gave you has credit for buying a number. Freshly
  purchased numbers have a **14-day release hold** - that's expected.
- The app is built on SignalWire's **native** APIs (SWML / Relay REST), not the
  Twilio Compatibility API (cXML). You're free to choose your approach, but mixing
  the two can bring challenges.

Good luck - have fun with it.
