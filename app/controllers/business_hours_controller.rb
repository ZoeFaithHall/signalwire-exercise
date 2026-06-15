class BusinessHoursController < ApplicationController
  before_action :require_onboarding

  # Save the after-hours routing config. Like ForwardingController, this needs no
  # SignalWire call. The inbound webhook reads the current settings from the
  # database on every call (Account#destination_for).
  def update
    if account.update(business_hours_params)
      redirect_to dashboard_path, notice: "After-hours routing updated."
    else
      redirect_to dashboard_path, alert: account.errors.full_messages.to_sentence
    end
  end

  private

  def business_hours_params
    params.permit(
      :timezone,
      :business_hours_start,
      :business_hours_end,
      :weekend_business_hours,
      :overnight_number
    ).transform_values { |v| v.is_a?(String) ? v.strip.presence : v }
  end
end