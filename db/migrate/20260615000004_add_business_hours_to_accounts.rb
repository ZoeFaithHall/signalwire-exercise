class AddBusinessHoursToAccounts < ActiveRecord::Migration[7.2]
  def change
    # After-hours routing configuration. All five are nullable. An account with these
    # unset behaves exactly as before (always business hours, forward as usual),
    # so the feature is purely opt-in and the migration is safe for existing data.
    #
    # start/end are time columns. We only care about the clock time, not the
    # date. "Business hours" is interpreted in `timezone` (a single zone for the
    # whole app, matching config.time_zone, the single-tenant model).
    add_column :accounts, :timezone,               :string
    add_column :accounts, :business_hours_start,   :time
    add_column :accounts, :business_hours_end,     :time
    add_column :accounts, :weekend_business_hours, :boolean, null: false, default: false
    add_column :accounts, :overnight_number,       :string
  end
end