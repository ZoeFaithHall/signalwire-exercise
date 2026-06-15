# Keeps the active SignalWire number pointed at our current public webhook URL.
#
# The cloudflared quick-tunnel URL changes every time the tunnel restarts, so we
# reconcile: compare the URL we last pushed (PhoneNumber#webhook_url) with the
# current public URL, and PUT the new one to SignalWire when they differ.
#
# Called automatically on dashboard load and at the end of onboarding, and
# on demand via the "Re-sync" button / `rake signalwire:sync_webhook`.
module WebhookSync
  Result = Struct.new(:status, :message) do
    def ok? = status == :ok
  end

  module_function

  def call(force: false)
    account = Account.instance
    number  = PhoneNumber.active

    return Result.new(:skip, "Onboarding isn't complete yet.") unless account.onboarded? && number
    return Result.new(:skip, "SignalWire credentials aren't configured.") unless SignalwireClient.configured?

    public_url = PublicUrl.current
    if public_url.blank?
      return Result.new(:error, "No public URL yet — is the cloudflared tunnel running?")
    end

    webhook_url = account.inbound_webhook_url(public_url)
    if !force && number.webhook_url == webhook_url
      return Result.new(:ok, "Webhook in sync: #{webhook_url}")
    end

    SignalwireClient.new.set_inbound_webhook(number.signalwire_id, webhook_url)
    number.update!(webhook_url: webhook_url, webhook_synced_at: Time.current)
    Result.new(:ok, "Webhook synced to #{webhook_url}")
  rescue SignalwireClient::Error => e
    Result.new(:error, e.message)
  rescue StandardError => e
    Rails.logger.error("WebhookSync failed: #{e.class}: #{e.message}")
    Result.new(:error, "Unexpected error: #{e.message}")
  end
end
