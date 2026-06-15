# Resolves the app's current public base URL — the address SignalWire uses to
# reach our inbound-call webhook.
#
# Priority:
#   1. PUBLIC_URL env var (set this if you run your own tunnel / stable domain).
#   2. The cloudflared quick tunnel, discovered by scanning its log file for the
#      randomly-assigned *.trycloudflare.com hostname (cloudflared only prints
#      this URL to its log — there is no metrics/API endpoint for it).
module PublicUrl
  TRYCLOUDFLARE = %r{https://[a-z0-9-]+\.trycloudflare\.com}

  module_function

  def current
    explicit = ENV["PUBLIC_URL"].to_s.strip
    return explicit.chomp("/") if explicit.present?

    from_cloudflared_log
  end

  def from_cloudflared_log
    path = ENV.fetch("CLOUDFLARED_LOG", "/cloudflared/cloudflared.log")
    return nil unless File.exist?(path)

    # Use the last match — on restart cloudflared appends a fresh URL.
    File.read(path).scan(TRYCLOUDFLARE).last
  rescue StandardError => e
    Rails.logger.warn("PublicUrl: could not read cloudflared log: #{e.message}")
    nil
  end
end
