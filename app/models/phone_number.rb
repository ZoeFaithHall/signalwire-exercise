# The SignalWire phone number (DID) this line owns. Single-tenant, so there is
# at most one active number — the most recently provisioned row.
class PhoneNumber < ApplicationRecord
  validates :signalwire_id, :e164, presence: true

  def self.active
    order(created_at: :desc).first
  end

  def webhook_in_sync?(expected_url)
    expected_url.present? && webhook_url == expected_url
  end
end
