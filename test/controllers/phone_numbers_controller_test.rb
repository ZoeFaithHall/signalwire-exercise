require "test_helper"

class PhoneNumbersControllerTest < ActionDispatch::IntegrationTest
  # Stand-in for SignalwireClient. `release` is configurable so we can exercise
  # both the success path and the "SignalWire refused" path.
  class FakeClient
    attr_reader :released

    def initialize(release: true)
      @release = release
    end

    def release_number(id)
      @released = id
      raise SignalwireClient::Error, "number is on a 14-day hold" if @release == :error

      true
    end
  end

  setup do
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    sign_in
    @number = PhoneNumber.create!(signalwire_id: "sw-1", e164: "+15550000000")
    Account.instance.update!(forwarding_number: "+15551230000", onboarded_at: Time.current)
  end

  test "releases the number and resets onboarding" do
    fake = FakeClient.new

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        assert_difference "PhoneNumber.count", -1 do
          post release_phone_number_path
        end
      end
    end

    assert_equal "sw-1", fake.released
    assert_redirected_to onboarding_path
    account = Account.instance
    assert_nil account.forwarding_number
    assert_not account.onboarded?
  end

  test "clears local state even when SignalWire refuses to release" do
    fake = FakeClient.new(release: :error)

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        assert_difference "PhoneNumber.count", -1 do
          post release_phone_number_path
        end
      end
    end

    # The number is gone locally and the user is moved on, but the failure is surfaced.
    assert_redirected_to onboarding_path
    assert_match(/Removed it locally/, flash[:alert])
  end

  test "skips the API entirely when SignalWire is not configured" do
    SignalwireClient.stub(:configured?, false) do
      assert_difference "PhoneNumber.count", -1 do
        post release_phone_number_path
      end
    end

    assert_redirected_to onboarding_path
  end

  test "does nothing when there is no number to release" do
    @number.destroy

    assert_no_difference "PhoneNumber.count" do
      post release_phone_number_path
    end
    assert_redirected_to dashboard_path
    assert_match(/No number to release/, flash[:alert])
  end

  test "requires login" do
    delete logout_path
    post release_phone_number_path
    assert_redirected_to login_path
  end
end
