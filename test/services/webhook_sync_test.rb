require "test_helper"

class WebhookSyncTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :synced

    def set_inbound_webhook(id, url)
      @synced = [ id, url ]
      "ok"
    end
  end

  def onboarded_account
    Account.instance.tap { |a| a.update!(forwarding_number: "+15551230000", onboarded_at: Time.current) }
  end

  def active_number(attrs = {})
    PhoneNumber.create!({ signalwire_id: "sw-1", e164: "+15550000000" }.merge(attrs))
  end

  test "skips when onboarding is incomplete" do
    assert_equal :skip, WebhookSync.call.status
  end

  test "skips when SignalWire is not configured" do
    onboarded_account
    active_number
    SignalwireClient.stub(:configured?, false) do
      assert_equal :skip, WebhookSync.call.status
    end
  end

  test "errors when there is no public URL" do
    onboarded_account
    active_number
    SignalwireClient.stub(:configured?, true) do
      PublicUrl.stub(:current, nil) do
        result = WebhookSync.call
        assert_equal :error, result.status
        assert_match(/public URL/, result.message)
      end
    end
  end

  test "no-ops when already in sync and not forced" do
    account = onboarded_account
    public_url = "https://tunnel.example"
    active_number(webhook_url: account.inbound_webhook_url(public_url))
    fake = FakeClient.new

    SignalwireClient.stub(:configured?, true) do
      PublicUrl.stub(:current, public_url) do
        SignalwireClient.stub(:new, fake) do
          result = WebhookSync.call
          assert result.ok?
          assert_nil fake.synced, "should not push to SignalWire when already in sync"
        end
      end
    end
  end

  test "pushes the token-bearing URL when out of sync" do
    account = onboarded_account
    public_url = "https://tunnel.example"
    number = active_number(webhook_url: nil)
    fake = FakeClient.new

    SignalwireClient.stub(:configured?, true) do
      PublicUrl.stub(:current, public_url) do
        SignalwireClient.stub(:new, fake) do
          result = WebhookSync.call
          assert result.ok?
          assert_equal [ number.signalwire_id, account.inbound_webhook_url(public_url) ], fake.synced
          assert_equal account.inbound_webhook_url(public_url), number.reload.webhook_url
        end
      end
    end
  end
end
