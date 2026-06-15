# Single-tenant app: there is exactly one Account row holding app-wide settings.
class Account < ApplicationRecord
  E164 = /\A\+[1-9]\d{1,14}\z/

  # Shared secret SignalWire must present on inbound-call webhooks. Generated
  # on create; see CallsController#verify_webhook_token. The token is embedded in
  # the webhook URL (inbound_webhook_url) and therefore lives in plaintext in
  # PhoneNumber#webhook_url and in the number's SignalWire config. To rotate it,
  # call `account.regenerate_webhook_token` then re-sync (WebhookSync.call(force: true)
  # / the dashboard "Re-sync" button) so SignalWire gets the new URL.
  has_secure_token :webhook_token

  validates :forwarding_number,
            format: { with: E164, message: "must be in E.164 format, e.g. +15551234567" },
            allow_blank: true

  # The overnight destination is optional, but if set it must be a real number
  # we can actually connect to — same rule as the primary forwarding number.
  validates :overnight_number,
            format: { with: E164, message: "must be in E.164 format, e.g. +15551234567" },
            allow_blank: true

  def self.instance
    first_or_create!
  end

  def onboarded?
    onboarded_at.present?
  end

  # Where should a call arriving at `time` be sent? This is the one routing
  # decision the inbound webhook asks for, kept here (not in the controller or
  # the SWML builder) so it's a pure, unit-testable function of stored config
  # and a clock.
  #
  # During business hours -> the primary forwarding number.
  # Outside them -> the overnight number, falling back to the primary one when
  # no overnight number is set. That fallback means turning the feature on can
  # never *remove* a destination: the worst case is today's behavior.
  def destination_for(time)
    return overnight_number.presence || forwarding_number unless business_hours?(time)

    forwarding_number
  end

  # Is `time` within configured business hours? Three things make a call
  # "after hours": a weekday clock outside the [start, end) window, or any
  # weekend when weekends aren't business hours.
  #
  # When business hours aren't configured we return true — "always open" — so an
  # account that hasn't opted in behaves exactly as it did before this feature.
  def business_hours?(time)
    return true unless business_hours_configured?

    local = time.in_time_zone(business_hours_zone)
    return false if weekend?(local) && !weekend_business_hours?

    within_window?(local)
  end

  # The token-authenticated URL SignalWire should POST inbound calls to. Single
  # source of truth for the webhook URL (built here, pushed by WebhookSync,
  # compared by PhoneNumber#webhook_in_sync?).
  def inbound_webhook_url(base_url)
    return if base_url.blank?

    "#{base_url}/calls/inbound?token=#{webhook_token}"
  end

  private

  def business_hours_configured?
    business_hours_start.present? && business_hours_end.present?
  end

  # Falls back to the app-wide zone (config.time_zone) when none is stored, so
  # the clock comparison always runs in a defined zone rather than UTC by accident.
  def business_hours_zone
    timezone.presence || Time.zone&.name || "UTC"
  end

  def weekend?(local)
    local.saturday? || local.sunday?
  end

  # Compare wall-clock minutes since midnight so a DB :time value (stored on a
  # 2000-01-01 epoch) and the live call time line up regardless of date. Start is
  # inclusive, end exclusive: a 17:00 call when hours end at 17:00 is after hours,
  # which is how "we close at 5" actually reads.
  def within_window?(local)
    now    = minutes_since_midnight(local)
    start  = minutes_since_midnight(business_hours_start)
    finish = minutes_since_midnight(business_hours_end)

    now >= start && now < finish
  end

  def minutes_since_midnight(value)
    value.hour * 60 + value.min
  end
end