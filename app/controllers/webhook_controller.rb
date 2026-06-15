class WebhookController < ApplicationController
  # Manual "Re-sync" button: force-push the current public webhook URL to the
  # active SignalWire number.
  def sync
    result = WebhookSync.call(force: true)
    if result.ok?
      redirect_to admin_path, notice: result.message
    else
      redirect_to admin_path, alert: result.message
    end
  end
end
