require "test_helper"

class SwmlTest < ActiveSupport::TestCase
  test "forward builds a connect section, passing the caller ID through" do
    doc = Swml.forward(to: "+15551230000")
    connect = doc.dig("sections", "main", 0, "connect")

    assert_equal "1.0.0", doc["version"]
    assert_equal "+15551230000", connect["to"]
    assert_equal "%{call.from}", connect["from"]
  end

  test "unconfigured plays a message then hangs up" do
    doc = Swml.unconfigured
    main = doc.dig("sections", "main")

    assert_equal "hangup", main.last
  end
end
