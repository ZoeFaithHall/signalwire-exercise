# Thin wrapper over the SignalWire *native* REST API (Relay REST + Fabric).
#
# We deliberately avoid the Compatibility (Twilio-style) API. Everything here
# talks to https://{space}.signalwire.com/api/relay/rest/... with HTTP Basic
# auth (project id + API token).
#
# Docs:
#   Search:   GET    /api/relay/rest/phone_numbers/search?areacode=&max_results=
#   Purchase: POST   /api/relay/rest/phone_numbers           { number }
#   List:     GET    /api/relay/rest/phone_numbers
#   Release:  DELETE /api/relay/rest/phone_numbers/{id}
#   Route:    PUT    /api/relay/rest/phone_numbers/{id}
#             { call_handler: "relay_script", call_relay_script_url:, call_request_method: "POST" }
class SignalwireClient
  class Error < StandardError; end

  def self.project_id = ENV["SIGNALWIRE_PROJECT_ID"].presence
  def self.api_token  = ENV["SIGNALWIRE_API_TOKEN"].presence
  def self.space      = ENV["SIGNALWIRE_SPACE_URL"].presence

  def self.configured?
    project_id && api_token && space
  end

  def initialize
    raise Error, "SignalWire credentials are not configured" unless self.class.configured?
  end

  PHONE_NUMBERS_PATH = "/api/relay/rest/phone_numbers".freeze

  # Returns an array of available-number hashes. Per the Relay REST schema each
  # hash has: number (E.164), region, city, and capabilities (an object of
  # voice/sms/mms/fax booleans). The list is wrapped in a top-level "data" key.
  def search_available_numbers(area_code:, max_results: 10)
    body = perform do |conn|
      conn.get("#{PHONE_NUMBERS_PATH}/search") do |req|
        req.params["areacode"]    = area_code if area_code.present?
        req.params["max_results"] = max_results
      end
    end
    extract_list(body, "data", "available_phone_numbers")
  end

  # Buys a number. Returns the created resource hash (id, number, ...).
  def purchase_number(e164)
    perform { |conn| conn.post(PHONE_NUMBERS_PATH, { number: e164 }) }
  end

  def list_numbers
    extract_list(perform { |conn| conn.get(PHONE_NUMBERS_PATH) }, "data")
  end

  def release_number(id)
    perform { |conn| conn.delete("#{PHONE_NUMBERS_PATH}/#{id}") }
    true
  end

  # Point the number's inbound-call handler at our external SWML webhook.
  def set_inbound_webhook(id, url)
    perform do |conn|
      conn.put("#{PHONE_NUMBERS_PATH}/#{id}", {
        call_handler:          "relay_script",
        call_relay_script_url: url,
        call_request_method:   "POST"
      })
    end
  end

  private

  # Runs an HTTP call against the connection, normalizing every failure mode
  # (non-2xx responses *and* transport errors like timeouts / connection
  # refused) into a single SignalwireClient::Error for callers to rescue.
  def perform
    handle(yield(connection))
  rescue Faraday::Error => e
    raise Error, "SignalWire request failed: #{e.message}"
  end

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.request :authorization, :basic, self.class.project_id, self.class.api_token
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.options.timeout = 15
      f.options.open_timeout = 5
    end
  end

  def base_url
    host = self.class.space.to_s.sub(%r{\Ahttps?://}, "").chomp("/")
    host = "#{host}.signalwire.com" unless host.include?(".")
    "https://#{host}"
  end

  def handle(response)
    return response.body if response.success?

    detail =
      if response.body.is_a?(Hash)
        (response.body["errors"] || response.body["message"] || response.body).to_s
      else
        response.body.to_s
      end
    raise Error, "SignalWire API returned #{response.status}: #{detail.to_s.truncate(300)}"
  end

  # Search/list endpoints sometimes return a bare array and sometimes wrap it
  # in a "data"/"available_phone_numbers" key. Handle both.
  def extract_list(body, *keys)
    return body if body.is_a?(Array)
    return [] unless body.is_a?(Hash)

    keys.each { |k| return body[k] if body[k].is_a?(Array) }
    body["data"].is_a?(Array) ? body["data"] : []
  end
end
