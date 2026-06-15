class PhoneNumbersController < ApplicationController
  # Release the current number from SignalWire and reset onboarding.
  def release
    number = PhoneNumber.active
    return redirect_to dashboard_path, alert: "No number to release." unless number

    if SignalwireClient.configured?
      begin
        SignalwireClient.new.release_number(number.signalwire_id)
      rescue SignalwireClient::Error => e
        # Recently purchased numbers have a 14-day hold on SignalWire; surface
        # the error but still clear local state so the user can move on.
        flash[:alert] = "Couldn't release the number with the provider (#{e.message}). " \
                        "Removed it locally — you may need to release it from the provider later."
      end
    end

    number.destroy
    account.update(forwarding_number: nil, onboarded_at: nil)
    redirect_to onboarding_path, notice: "Number released. Let's set up a new one."
  end
end
