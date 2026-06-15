class ApplicationController < ActionController::Base
  before_action :require_login

  private

  # Single-tenant auth: one shared password, kept in a session flag.
  def require_login
    return if logged_in?

    redirect_to login_path, alert: "Please sign in to continue."
  end

  def logged_in?
    session[:logged_in] == true
  end
  helper_method :logged_in?

  # Pages that assume a provisioned line bounce to onboarding until setup is done.
  def require_onboarding
    redirect_to onboarding_path unless account.onboarded? && PhoneNumber.active
  end

  # The single Account row holds app-wide settings (forwarding number, onboarding state).
  def account
    @account ||= Account.instance
  end
  helper_method :account
end
