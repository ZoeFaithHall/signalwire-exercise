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

  # --- after-hours routing -------------------------------------------------
  #
  # destination_for/business_hours? are pure functions of stored config and a
  # clock, so we test them directly with fixed Times — no network, no stubs.
  # All times below are constructed in the account's configured zone.

  def biz_account(attrs = {})
    Account.new({
      forwarding_number:      "+15551110000",
      overnight_number:       "+15559990000",
      timezone:               "America/New_York",
      business_hours_start:   "09:00",
      business_hours_end:     "17:00",
      weekend_business_hours: false
    }.merge(attrs))
  end

  # A Tuesday (weekday) at the given local hour:min in the account's zone.
  def weekday_at(account, hour, min = 0)
    Time.use_zone(account.timezone) { Time.zone.local(2026, 6, 16, hour, min) }
  end

  # A Saturday at the given local hour in the account's zone.
  def weekend_at(account, hour, min = 0)
    Time.use_zone(account.timezone) { Time.zone.local(2026, 6, 20, hour, min) }
  end

  test "weekday inside the window is business hours" do
    account = biz_account
    assert account.business_hours?(weekday_at(account, 12))
    assert_equal "+15551110000", account.destination_for(weekday_at(account, 12))
  end

  test "the start of the window is inclusive" do
    account = biz_account
    assert account.business_hours?(weekday_at(account, 9, 0))
  end

  test "the end of the window is exclusive" do
    account = biz_account
    assert_not account.business_hours?(weekday_at(account, 17, 0))
    assert_equal "+15559990000", account.destination_for(weekday_at(account, 17, 0))
  end

  test "before opening routes to the overnight number" do
    account = biz_account
    assert_not account.business_hours?(weekday_at(account, 8, 59))
    assert_equal "+15559990000", account.destination_for(weekday_at(account, 8, 59))
  end

  test "weekends are after hours unless weekend hours are enabled" do
    account = biz_account
    assert_not account.business_hours?(weekend_at(account, 12))
    assert_equal "+15559990000", account.destination_for(weekend_at(account, 12))
  end

  test "weekends inside the window are business hours when enabled" do
    account = biz_account(weekend_business_hours: true)
    assert account.business_hours?(weekend_at(account, 12))
    assert_equal "+15551110000", account.destination_for(weekend_at(account, 12))
  end

  test "after hours with no overnight number falls back to the forwarding number" do
    account = biz_account(overnight_number: nil)
    assert_equal "+15551110000", account.destination_for(weekday_at(account, 22))
  end

  test "with hours unconfigured every time is business hours" do
    account = biz_account(business_hours_start: nil, business_hours_end: nil)
    assert account.business_hours?(weekday_at(account, 3))
    assert account.business_hours?(weekend_at(account, 3))
    assert_equal "+15551110000", account.destination_for(weekday_at(account, 3))
  end

  test "overnight_number must be E.164 when present" do
    account = biz_account(overnight_number: "555-1234")
    assert_not account.valid?
    assert_includes account.errors[:overnight_number].to_s, "E.164"
  end

  test "a blank overnight_number is allowed" do
    assert biz_account(overnight_number: "").valid?
  end
end