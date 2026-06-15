# Brute-force protection for the single shared-password login.
#
# Rack::Attack is auto-inserted into the middleware stack by its railtie. We use
# a dedicated in-memory store so throttling works the same in every environment
# (the app's Rails.cache is a null_store in development) — fine here because the
# app runs as a single Puma process.
class Rack::Attack
  self.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Throttle login attempts by IP: 10 POSTs to /login per minute.
  throttle("logins/ip", limit: 10, period: 60) do |req|
    req.ip if req.post? && req.path == "/login"
  end

  # Abuse backstop for the public inbound-call webhook. A valid per-install token
  # is still required (CallsController#verify_webhook_token); this just caps a
  # flood from a single source. The limit sits far above any realistic
  # single-number call volume, so it never trips legitimate bursts of calls.
  throttle("inbound/ip", limit: 300, period: 60) do |req|
    req.ip if req.post? && req.path == "/calls/inbound"
  end

  # Return a friendly 429 instead of a blank one.
  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many attempts. Please wait a minute and try again.\n" ] ]
  end
end
