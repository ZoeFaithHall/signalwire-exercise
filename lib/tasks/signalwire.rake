namespace :signalwire do
  desc "Push the current public webhook URL to the active SignalWire number"
  task sync_webhook: :environment do
    result = WebhookSync.call(force: true)
    puts "[signalwire:sync_webhook] #{result.status}: #{result.message}"
  end
end
