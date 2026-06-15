require "test_helper"

class ForwardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    sign_in
  end

  test "updates the forwarding number (trimming whitespace)" do
    patch forwarding_path, params: { forwarding_number: " +15559998888 " }

    assert_redirected_to dashboard_path
    assert_equal "+15559998888", Account.instance.forwarding_number
  end

  test "rejects a non-E.164 number and leaves the destination unchanged" do
    Account.instance.update!(forwarding_number: "+15551230000")

    patch forwarding_path, params: { forwarding_number: "nonsense" }

    assert_redirected_to dashboard_path
    assert_equal "+15551230000", Account.instance.reload.forwarding_number
  end

  test "requires login" do
    delete logout_path
    patch forwarding_path, params: { forwarding_number: "+15559998888" }
    assert_redirected_to login_path
  end
end
