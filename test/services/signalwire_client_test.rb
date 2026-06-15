require "test_helper"

class SignalwireClientTest < ActiveSupport::TestCase
  # Minimal stand-in for a Faraday::Response.
  class FakeResponse
    attr_reader :status, :body

    def initialize(success, status, body)
      @success = success
      @status  = status
      @body    = body
    end

    def success? = @success
  end

  setup do
    @saved = ENV.to_h.slice("SIGNALWIRE_PROJECT_ID", "SIGNALWIRE_API_TOKEN", "SIGNALWIRE_SPACE_URL")
    ENV["SIGNALWIRE_PROJECT_ID"] = "proj"
    ENV["SIGNALWIRE_API_TOKEN"]  = "tok"
    ENV["SIGNALWIRE_SPACE_URL"]  = "example"
  end

  teardown do
    %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN SIGNALWIRE_SPACE_URL].each { |k| ENV.delete(k) }
    @saved.each { |k, v| ENV[k] = v }
  end

  test "configured? requires all three credentials" do
    assert SignalwireClient.configured?
    ENV.delete("SIGNALWIRE_API_TOKEN")
    assert_not SignalwireClient.configured?
  end

  test "new raises when not configured" do
    ENV.delete("SIGNALWIRE_SPACE_URL")
    assert_raises(SignalwireClient::Error) { SignalwireClient.new }
  end

  test "wraps Faraday transport errors as SignalwireClient::Error" do
    client = SignalwireClient.new
    conn = Object.new
    conn.define_singleton_method(:get) { |*| raise Faraday::TimeoutError, "timed out" }

    client.stub(:connection, conn) do
      error = assert_raises(SignalwireClient::Error) { client.list_numbers }
      assert_match(/SignalWire request failed/, error.message)
    end
  end

  test "raises on non-2xx responses, surfacing the error detail" do
    client = SignalwireClient.new
    conn = Object.new
    conn.define_singleton_method(:post) { |*| FakeResponse.new(false, 422, { "errors" => "bad number" }) }

    client.stub(:connection, conn) do
      error = assert_raises(SignalwireClient::Error) { client.purchase_number("+1") }
      assert_match(/422/, error.message)
      assert_match(/bad number/, error.message)
    end
  end

  test "search extracts the available_phone_numbers list" do
    client = SignalwireClient.new
    body = { "available_phone_numbers" => [ { "e164" => "+15551112222" } ] }
    conn = Object.new
    conn.define_singleton_method(:get) { |*_args, &_blk| FakeResponse.new(true, 200, body) }

    client.stub(:connection, conn) do
      result = client.search_available_numbers(area_code: "555")
      assert_equal "+15551112222", result.first["e164"]
    end
  end

  test "base_url normalizes a bare space subdomain" do
    assert_equal "https://example.signalwire.com", SignalwireClient.new.send(:base_url)
  end

  test "base_url passes through a full space URL" do
    ENV["SIGNALWIRE_SPACE_URL"] = "https://myspace.signalwire.com/"
    assert_equal "https://myspace.signalwire.com", SignalwireClient.new.send(:base_url)
  end

  test "extract_list handles arrays, wrapped lists, and neither" do
    client = SignalwireClient.new
    assert_equal [ 1, 2 ], client.send(:extract_list, [ 1, 2 ], "data")
    assert_equal [ 3 ], client.send(:extract_list, { "data" => [ 3 ] }, "data")
    assert_equal [ 4 ], client.send(:extract_list, { "available_phone_numbers" => [ 4 ] }, "available_phone_numbers")
    assert_equal [], client.send(:extract_list, { "foo" => "bar" }, "data")
  end
end
