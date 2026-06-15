require "test_helper"

class CallsControllerTest < ActionDispatch::IntegrationTest
  def token
    Account.instance.webhook_token
  end

  def post_inbound(params: {}, with_token: true)
    params = params.merge(token: token) if with_token
    post inbound_call_path, params: params, as: :json
  end

  test "returns SWML that forwards to the configured number" do
    Account.instance.update!(forwarding_number: "+15551230000", onboarded_at: Time.current)

    post_inbound(params: { call: { from: "+15557654321", to: "+15551112222" } })

    assert_response :success
    connect = response.parsed_body.dig("sections", "main", 0, "connect")
    assert_equal "+15551230000", connect["to"]
  end

  test "returns hangup SWML when no forwarding number is set" do
    Account.instance.update!(forwarding_number: nil, onboarded_at: nil)

    post_inbound(params: { call: { from: "+15557654321", to: "+15551112222" } })

    assert_response :success
    assert_equal "hangup", response.parsed_body.dig("sections", "main").last
  end

  test "records each inbound call" do
    Account.instance.update!(forwarding_number: "+15551230000", onboarded_at: Time.current)

    assert_difference "CallLog.count", 1 do
      post_inbound(params: { call: { from: "+1", to: "+2" } })
    end
  end

  test "normalizes SIP URIs to E.164 in the call log" do
    Account.instance.update!(forwarding_number: "+15551230000", onboarded_at: Time.current)

    post_inbound(params: { call: {
      from: "sip:+15557654321@example.com",
      to:   "sip:+15551112222@example.com"
    } })

    log = CallLog.order(:created_at).last
    assert_equal "+15557654321", log.from
    assert_equal "+15551112222", log.to
  end

  test "rejects requests with no token" do
    Account.instance # ensure the singleton (and its token) exists

    assert_no_difference "CallLog.count" do
      post_inbound(params: { call: { from: "+1", to: "+2" } }, with_token: false)
    end
    assert_response :forbidden
  end

  test "rejects requests with the wrong token" do
    Account.instance

    assert_no_difference "CallLog.count" do
      post inbound_call_path, params: { token: "not-the-real-token", call: { from: "+1", to: "+2" } }, as: :json
    end
    assert_response :forbidden
  end

  test "inbound webhook is POST-only" do
    assert_recognizes({ controller: "calls", action: "inbound" }, { path: "/calls/inbound", method: :post })
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/calls/inbound", method: :get)
    end
  end
end
