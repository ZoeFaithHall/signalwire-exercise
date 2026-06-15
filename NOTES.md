# Notes

## What I built

After-hours routing (feedback item 5). During business hours, calls ring the
primary forwarding number. Outside business hours, they ring a separate
overnight number. The owner sets the hours, the overnight number, a timezone,
and whether weekends count, from the dashboard.

I picked it because "is it business hours right now" is a fact, not a judgment
call. It computes from stored config and a clock. The routing follows from it.
Nothing in the path of a live call needs a human, which is the kind of decision
worth handing to a machine.

## Where the logic lives

The decision is a method on `Account`:

- `business_hours?(time)` answers the factual question.
- `destination_for(time)` turns that into a number.
- `CallsController#inbound` calls `destination_for(Time.current)` and forwards.
- `Swml` didn't change.

I kept it on the model so it's a pure function of config and a clock. That makes
every boundary testable with fixed `Time` values, no network and no stubs. The
controller change ended up being two lines.

## Decisions and tradeoffs

Every new column is nullable. An account that hasn't set hours behaves exactly
as before: always open, forward as usual. So the migration is safe on existing
data and the feature is opt-in. If hours are set but no overnight number is,
after-hours calls fall back to the primary number. The worst case from turning
this on is today's behavior, not a dropped call.

The window is start-inclusive, end-exclusive: a 17:00 call when hours end at
17:00 is after hours. I compare minutes since midnight rather than `Time`
objects, because a Postgres `:time` value comes back on a 2000-01-01 epoch and
comparing that to a live call time is meaningless.

One daily window plus a weekday/weekend flag, not per-day hours. It covers what
the customer asked for without seven separate windows to configure. One account
timezone, matching the app's existing single-tenant `config.time_zone`.

The dashboard banner reads the same `business_hours?`/`destination_for` methods
the webhook uses, so it can't show a state that disagrees with what a real call
does. That also covers feedback item 3: it's clear which calls are business
calls and where they're going.

## Left out on purpose

- Windows that cross midnight (open 18:00 to 02:00). The window assumes start <
  end. The customer described a daytime close, so I scoped to that.
- Per-day hours and holidays. Weekday/weekend covers the stated need.
- A real timezone picker. It's a text field now, which accepts a typo and would
  fall back to UTC. A `time_zone_select` dropdown is the fix.
- A routing column on `CallLog`. You can infer it from `forwarded_to`, so I
  didn't add one for a short exercise.

## Next

Overnight windows first, since it's the likeliest real gap. Then the timezone
dropdown, since the current field can misroute silently. Then a `routed_as`
column on `CallLog` so the call list shows business vs after-hours at a glance.

## Tests

- `account_test.rb`: the decision across every boundary (start, end, before
  open, weekend on/off, fallback with no overnight number, unconfigured
  always-open, overnight E.164 validation).
- `calls_controller_test.rb`: the live endpoint returns SWML connecting to the
  right number in both windows, using `travel_to` to freeze the clock.
- `business_hours_controller_test.rb`: the form persists, rejects a bad number
  without corrupting state, clears to nil on blank, handles the unchecked
  weekend box, enforces login.

Run with `docker compose run --rm web bin/rails test`.