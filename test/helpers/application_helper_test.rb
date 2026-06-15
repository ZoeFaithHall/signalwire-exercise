require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "masked_webhook_url hides the token but keeps the rest of the URL" do
    masked = masked_webhook_url("https://x.example/calls/inbound?token=supersecret")
    assert_no_match(/supersecret/, masked)
    assert_match(%r{https://x\.example/calls/inbound\?token=••••••}, masked)
  end

  test "masked_webhook_url passes through blank and token-less URLs" do
    assert_equal "", masked_webhook_url("")
    assert_nil masked_webhook_url(nil)
    assert_equal "https://x.example/up", masked_webhook_url("https://x.example/up")
  end

  test "number_capabilities lists the enabled keys of a capabilities object" do
    assert_equal "voice, sms",
                 number_capabilities("voice" => true, "sms" => true, "fax" => false)
  end

  test "number_capabilities tolerates a plain array" do
    assert_equal "voice, fax", number_capabilities([ "voice", "fax" ])
  end

  test "number_capabilities is blank-safe" do
    assert_equal "", number_capabilities(nil)
  end
end
