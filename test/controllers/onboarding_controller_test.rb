require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  # Stand-in for SignalwireClient that records what it was asked to do.
  class FakeClient
    attr_reader :purchased, :released

    def initialize(search: [], purchase: {})
      @search = search
      @purchase = purchase
    end

    def search_available_numbers(**) = @search

    def purchase_number(e164)
      @purchased = e164
      @purchase
    end

    def release_number(id)
      @released = id
      true
    end

    def set_inbound_webhook(*) = "ok"
  end

  setup do
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    sign_in
  end

  test "search lists available numbers using the API's `number` field" do
    fake = FakeClient.new(search: [
      { "number" => "+15551112222", "region" => "NY",
        "capabilities" => { "voice" => true, "sms" => false } }
    ])

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        post onboarding_search_path, params: { area_code: "555" }
      end
    end

    assert_response :success
    # The displayed number and the hidden "buy" field both come from `number`.
    assert_select "input[type=hidden][name=number][value='+15551112222']"
    assert_select "td", text: /voice/
    assert_select "td", text: /sms/, count: 0 # disabled capability is omitted
  end

  test "purchase records the number from the API response" do
    fake = FakeClient.new(purchase: { "id" => "sw-99", "number" => "+15551112222", "name" => "Biz line" })

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        assert_difference "PhoneNumber.count", 1 do
          post onboarding_purchase_path, params: { number: "+15551112222", area_code: "555" }
        end
      end
    end

    number = PhoneNumber.active
    assert_equal "+15551112222", number.e164
    assert_equal "sw-99", number.signalwire_id
    assert_equal "+15551112222", fake.purchased
  end

  test "purchase releases the number when it can't be recorded locally" do
    # SignalWire reports success but returns no usable number, so the local
    # PhoneNumber fails validation (blank e164). We were billed for it, so the
    # controller must release it rather than orphan it.
    fake = FakeClient.new(purchase: { "id" => "sw-orphan" })

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        assert_no_difference "PhoneNumber.count" do
          post onboarding_purchase_path, params: {} # no number anywhere -> blank e164
        end
      end
    end

    assert_equal "sw-orphan", fake.released, "should release the number we were billed for"
    assert_redirected_to onboarding_path
    assert_match(/Could not purchase/, flash[:alert])
  end

  test "purchase surfaces the original error even if releasing the orphan also fails" do
    # release_number raising must not mask the original RecordInvalid.
    fake = FakeClient.new(purchase: { "id" => "sw-orphan" })
    fake.define_singleton_method(:release_number) do |_id|
      raise SignalwireClient::Error, "14-day hold"
    end

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        assert_no_difference "PhoneNumber.count" do
          post onboarding_purchase_path, params: {}
        end
      end
    end

    assert_redirected_to onboarding_path
    assert_match(/Could not purchase/, flash[:alert])
  end

  test "purchase refuses (and skips the API) when a number already exists" do
    PhoneNumber.create!(signalwire_id: "sw-1", e164: "+15550000000")
    fake = FakeClient.new(purchase: { "id" => "sw-2", "number" => "+15551112222" })

    SignalwireClient.stub(:configured?, true) do
      SignalwireClient.stub(:new, fake) do
        assert_no_difference "PhoneNumber.count" do
          post onboarding_purchase_path, params: { number: "+15551112222" }
        end
      end
    end

    assert_redirected_to onboarding_path
    assert_nil fake.purchased, "should not hit the SignalWire API when a number already exists"
  end

  test "forwarding step saves the destination and completes onboarding" do
    PhoneNumber.create!(signalwire_id: "sw-1", e164: "+15550000000")

    WebhookSync.stub(:call, WebhookSync::Result.new(:ok, "synced")) do
      post onboarding_forwarding_path, params: { forwarding_number: " +15551230000 " }
    end

    assert_redirected_to dashboard_path
    assert Account.instance.onboarded?
    assert_equal "+15551230000", Account.instance.forwarding_number
  end

  test "forwarding step rejects a non-E.164 destination" do
    PhoneNumber.create!(signalwire_id: "sw-1", e164: "+15550000000")

    post onboarding_forwarding_path, params: { forwarding_number: "555-1234" }

    assert_response :success # re-renders the wizard with errors
    assert_not Account.instance.onboarded?
  end
end
