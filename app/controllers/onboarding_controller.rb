class OnboardingController < ApplicationController
  # The wizard has two steps:
  #   1. :search    — search SignalWire for an available number and buy one
  #   2. :forwarding — set the destination number calls are forwarded to
  def show
    redirect_to dashboard_path and return if account.onboarded? && PhoneNumber.active

    @phone_number = PhoneNumber.active
    @step = @phone_number ? :forwarding : :search
  end

  def search
    @step = :search
    @searched = true
    @available_numbers = []

    if SignalwireClient.configured?
      begin
        @available_numbers = SignalwireClient.new.search_available_numbers(
          area_code: params[:area_code], max_results: 10
        )
      rescue SignalwireClient::Error => e
        flash.now[:alert] = e.message
      end
    else
      flash.now[:alert] = "The phone service isn't configured yet — add your credentials to .env first."
    end

    render :show
  end

  def purchase
    unless SignalwireClient.configured?
      return redirect_to onboarding_path, alert: "The phone service isn't configured yet — add your credentials to .env first."
    end

    # Single-tenant: one active number at a time. Guards against a double-submit
    # buying (and orphaning) a second number.
    if PhoneNumber.active
      return redirect_to onboarding_path, notice: "You already have a number. Finish setup below."
    end

    client = SignalwireClient.new
    result = client.purchase_number(params[:number])

    begin
      PhoneNumber.create!(
        signalwire_id: result["id"],
        e164:          result["number"].presence || params[:number],
        friendly_name: result["name"],
        area_code:     params[:area_code],
        purchased_at:  Time.current
      )
    rescue ActiveRecord::RecordInvalid
      # We were billed for a number we couldn't record locally — release it so it
      # isn't orphaned (best effort; SignalWire's 14-day hold may block this). A
      # failure here must not mask the original RecordInvalid, so swallow it.
      begin
        client.release_number(result["id"]) if result["id"].present?
      rescue SignalwireClient::Error => release_error
        Rails.logger.error("Failed to release orphaned number #{result['id']}: #{release_error.message}")
      end
      raise
    end

    redirect_to onboarding_path, notice: "Purchased #{params[:number]}. Now choose where to forward calls."
  rescue SignalwireClient::Error, ActiveRecord::RecordInvalid => e
    redirect_to onboarding_path, alert: "Could not purchase that number: #{e.message}"
  end

  def forwarding
    number = PhoneNumber.active
    return redirect_to onboarding_path, alert: "Pick a phone number first." unless number

    account.assign_attributes(
      forwarding_number: params[:forwarding_number].to_s.strip,
      onboarded_at:      Time.current
    )

    if account.save
      sync = WebhookSync.call(force: true)
      notice = "Setup complete — your line is live."
      notice += " (#{sync.message})" unless sync.ok?
      redirect_to dashboard_path, notice: notice
    else
      @step = :forwarding
      @phone_number = number
      flash.now[:alert] = account.errors.full_messages.to_sentence
      render :show
    end
  end
end
