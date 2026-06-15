class DashboardController < ApplicationController
  before_action :require_onboarding

  def show
    @phone_number = PhoneNumber.active
    @recent_calls = CallLog.recent
    # Silently keep the inbound route pointed at the current public URL (it
    # changes when the tunnel restarts). No-ops when already in sync; the status
    # and manual controls live on the admin page.
    WebhookSync.call
  end
end
