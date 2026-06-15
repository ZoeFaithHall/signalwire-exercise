class SessionsController < ApplicationController
  skip_before_action :require_login

  def new
    redirect_to root_path and return if logged_in?
  end

  def create
    if correct_password?(params[:password])
      # Rotate the session on privilege change to prevent session fixation.
      reset_session
      session[:logged_in] = true
      redirect_to root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Incorrect password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out."
  end

  private

  def correct_password?(input)
    expected = dashboard_password
    return false if input.blank?

    # Compare SHA-256 digests: constant-time and doesn't leak the password length.
    ActiveSupport::SecurityUtils.secure_compare(
      OpenSSL::Digest::SHA256.hexdigest(input.to_s),
      OpenSSL::Digest::SHA256.hexdigest(expected)
    )
  end

  def dashboard_password
    configured = ENV["DASHBOARD_PASSWORD"].presence
    # In production, refuse to fall back to the well-known default.
    if Rails.env.production? && (configured.nil? || configured == "changeme")
      raise "DASHBOARD_PASSWORD must be set to a non-default value in production"
    end

    # Defaults to "changeme" in development/test so the app is usable before .env is filled in.
    configured || "changeme"
  end
end
