class CreateAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.string   :forwarding_number
      t.datetime :onboarded_at
      t.string   :webhook_token

      t.timestamps
    end

    add_index :accounts, :webhook_token, unique: true
  end
end
