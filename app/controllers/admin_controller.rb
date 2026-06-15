class AdminController < ApplicationController
  before_action :require_onboarding

  # Operator view for the telephony plumbing the customer dashboard hides:
  # inbound-route sync status and number management.
  def show
    @phone_number     = PhoneNumber.active
    @public_url       = PublicUrl.current
    @expected_webhook = account.inbound_webhook_url(@public_url)
    # Reconcile and report so the page reflects the live state.
    @sync             = WebhookSync.call
  end
end
