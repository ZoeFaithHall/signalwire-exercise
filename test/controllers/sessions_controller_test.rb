require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Throttle state is process-global; start each test from a clean slate.
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  end

  test "rejects an incorrect password" do
    post login_path, params: { password: "nope" }
    assert_response :unprocessable_entity

    # Still logged out: a protected page bounces back to login.
    get dashboard_path
    assert_redirected_to login_path
  end

  test "signs in with the correct password" do
    post login_path, params: { password: "changeme" }
    assert_redirected_to root_path

    # Logged in now: the dashboard no longer redirects to login (onboarding instead).
    get dashboard_path
    assert_redirected_to onboarding_path
  end

  test "throttles repeated login attempts from one IP" do
    11.times do
      post login_path, params: { password: "wrong" }, headers: { "REMOTE_ADDR" => "9.9.9.9" }
    end
    assert_response :too_many_requests
  end
end
