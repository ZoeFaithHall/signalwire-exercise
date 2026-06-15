class ForwardingController < ApplicationController
  # Changing the forwarding number needs no SignalWire call: the inbound webhook
  # reads the current number from the database every time a call comes in.
  def update
    if account.update(forwarding_number: params[:forwarding_number].to_s.strip)
      redirect_to dashboard_path, notice: "Calls now forward to #{account.forwarding_number}."
    else
      redirect_to dashboard_path, alert: account.errors.full_messages.to_sentence
    end
  end
end
