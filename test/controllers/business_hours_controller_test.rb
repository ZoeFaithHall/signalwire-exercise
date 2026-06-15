require "test_helper"

class BusinessHoursControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    sign_in
    PhoneNumber.create!(signalwire_id: "sw-1", e164: "+15550000000")
    Account.instance.update!(forwarding_number: "+15551230000", onboarded_at: Time.current)
  end

  test "saves the after-hours routing settings" do
    patch business_hours_path, params: {
      timezone:             "America/New_York",
      business_hours_start: "09:00",
      business_hours_end:   "17:00",
      overnight_number:     "+15559990000",
      weekend_business_hours: "1"
    }

    assert_redirected_to dashboard_path
    account = Account.instance.reload
    assert_equal "America/New_York", account.timezone
    assert_equal "+15559990000", account.overnight_number
    assert account.weekend_business_hours
  end

  test "rejects a non-E.164 overnight number and leaves settings unchanged" do
    Account.instance.update!(overnight_number: "+15559990000")

    patch business_hours_path, params: { overnight_number: "nonsense" }

    assert_redirected_to dashboard_path
    assert_equal "+15559990000", Account.instance.reload.overnight_number
  end

  test "a blank overnight number clears the field" do
    Account.instance.update!(overnight_number: "+15559990000")

    patch business_hours_path, params: { overnight_number: "" }

    assert_redirected_to dashboard_path
    assert_nil Account.instance.reload.overnight_number
  end

  test "an unchecked weekend box turns the flag off" do
    Account.instance.update!(weekend_business_hours: true)

    # The form posts the hidden "0" when the box is unchecked.
    patch business_hours_path, params: { weekend_business_hours: "0" }

    assert_redirected_to dashboard_path
    assert_not Account.instance.reload.weekend_business_hours
  end

  test "requires login" do
    delete logout_path
    patch business_hours_path, params: { overnight_number: "+15559990000" }
    assert_redirected_to login_path
  end
end