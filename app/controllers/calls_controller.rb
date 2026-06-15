class CallsController < ApplicationController
  # SignalWire calls this endpoint on every inbound call and expects SWML back.
  # It's public (SignalWire isn't logged in) and CSRF-exempt, so we authenticate
  # it with a per-install secret token baked into the webhook URL we configure
  # on the number (Account#webhook_token / WebhookSync). SignalWire doesn't sign
  # native SWML script fetches, and we sit behind a tunnel that rewrites the
  # Host/proto (which would break signature validation anyway), so a shared
  # token on the URL is the right fit here.
  skip_before_action :require_login
  skip_forgery_protection
  before_action :verify_webhook_token

  def inbound
    # SignalWire POSTs a JSON body shaped like { "call": { "from": ..., "to": ... },
    # "vars": {...}, "params": {...} } when it fetches the SWML script. from/to
    # arrive either as bare E.164 or as a SIP URI ("sip:+15551231234@host"), so
    # normalize them for clean call logs. (Flat params are a defensive fallback.)
    from = normalize_number(params.dig(:call, :from).presence || params[:from])
    to   = normalize_number(params.dig(:call, :to).presence   || params[:to])

    forwarding = account.forwarding_number
    swml = forwarding.present? ? Swml.forward(to: forwarding) : Swml.unconfigured

    log_call(from: from, to: to, forwarding: forwarding)

    render json: swml
  end

  private

  # Pull the E.164 number out of a SIP URI; pass anything else through.
  def normalize_number(value)
    return value if value.blank?

    value[/\+\d+/] || value
  end

  def verify_webhook_token
    expected = account.webhook_token.to_s
    provided = params[:token].to_s
    # Compare digests so the check is constant-time regardless of length.
    return if expected.present? &&
              ActiveSupport::SecurityUtils.secure_compare(
                OpenSSL::Digest::SHA256.hexdigest(provided),
                OpenSSL::Digest::SHA256.hexdigest(expected)
              )

    head :forbidden
  end

  def log_call(from:, to:, forwarding:)
    CallLog.create!(
      from:         from,
      to:           to,
      forwarded_to: forwarding,
      status:       forwarding.present? ? "forwarded" : "unconfigured"
    )
  rescue StandardError => e
    # Logging must never break the call.
    Rails.logger.warn("Failed to record CallLog: #{e.message}")
  end
end
