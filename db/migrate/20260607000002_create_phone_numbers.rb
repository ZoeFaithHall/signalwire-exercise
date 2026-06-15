class CreatePhoneNumbers < ActiveRecord::Migration[7.2]
  def change
    create_table :phone_numbers do |t|
      t.string   :signalwire_id, null: false
      t.string   :e164,          null: false
      t.string   :friendly_name
      t.string   :area_code
      t.string   :webhook_url
      t.datetime :webhook_synced_at
      t.datetime :purchased_at

      t.timestamps
    end

    add_index :phone_numbers, :signalwire_id, unique: true
  end
end
