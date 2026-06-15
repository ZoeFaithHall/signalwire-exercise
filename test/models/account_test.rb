require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "generates a webhook token on create" do
    account = Account.create!
    assert account.webhook_token.present?
  end

  test "accepts a blank forwarding number" do
    account = Account.new(forwarding_number: "")
    assert account.valid?
  end

  test "accepts an E.164 forwarding number" do
    account = Account.new(forwarding_number: "+15551234567")
    assert account.valid?
  end

  test "rejects a non-E.164 forwarding number" do
    account = Account.new(forwarding_number: "555-1234")
    assert_not account.valid?
    assert_includes account.errors[:forwarding_number].to_s, "E.164"
  end

  test "inbound_webhook_url embeds the token" do
    account = Account.new(webhook_token: "abc123")
    assert_equal "https://example.com/calls/inbound?token=abc123",
                 account.inbound_webhook_url("https://example.com")
  end

  test "inbound_webhook_url is nil without a base URL" do
    assert_nil Account.new(webhook_token: "abc123").inbound_webhook_url(nil)
    assert_nil Account.new(webhook_token: "abc123").inbound_webhook_url("")
  end
end
