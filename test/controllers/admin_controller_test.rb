require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  end

  test "requires login" do
    get admin_path
    assert_redirected_to login_path
  end

  test "redirects to onboarding until a line is provisioned" do
    sign_in
    get admin_path
    assert_redirected_to onboarding_path
  end

  test "renders the routing status once onboarded" do
    sign_in
    PhoneNumber.create!(signalwire_id: "sw-1", e164: "+15550000000")
    Account.instance.update!(forwarding_number: "+15551230000", onboarded_at: Time.current)

    get admin_path

    assert_response :success
    assert_select "h2", text: "Inbound call routing"
  end
end
