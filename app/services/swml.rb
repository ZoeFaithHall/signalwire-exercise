# Builds SWML (SignalWire Markup Language) documents returned to SignalWire on
# inbound calls. SWML is plain JSON — see https://developer.signalwire.com/swml/
module Swml
  module_function

  # Forward the inbound call to `to`, passing the original caller's number
  # through as caller ID (%{call.from} is expanded by SignalWire at call time).
  def forward(to:, caller_id: "%{call.from}")
    {
      "version" => "1.0.0",
      "sections" => {
        "main" => [
          { "connect" => { "from" => caller_id, "to" => to } }
        ]
      }
    }
  end

  # Played when no forwarding number is set yet.
  def unconfigured(message = "This number isn't set up for call forwarding yet. Goodbye.")
    {
      "version" => "1.0.0",
      "sections" => {
        "main" => [
          { "play" => { "urls" => [ "say:#{message}" ] } },
          "hangup"
        ]
      }
    }
  end
end
