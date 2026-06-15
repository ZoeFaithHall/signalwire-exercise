# A record of each inbound call SignalWire forwarded through us.
class CallLog < ApplicationRecord
  # Most recent calls first — what the dashboard shows.
  scope :recent, ->(limit = 20) { order(created_at: :desc).limit(limit) }
end
