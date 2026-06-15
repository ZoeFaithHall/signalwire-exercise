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

  def self.instance
    first_or_create!
  end

  def onboarded?
    onboarded_at.present?
  end

  # The token-authenticated URL SignalWire should POST inbound calls to. Single
  # source of truth for the webhook URL (built here, pushed by WebhookSync,
  # compared by PhoneNumber#webhook_in_sync?).
  def inbound_webhook_url(base_url)
    return if base_url.blank?

    "#{base_url}/calls/inbound?token=#{webhook_token}"
  end
end
