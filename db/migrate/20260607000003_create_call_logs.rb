class CreateCallLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :call_logs do |t|
      t.string :from
      t.string :to
      t.string :forwarded_to
      t.string :status

      t.timestamps
    end

    # The dashboard lists recent calls ordered by created_at DESC.
    add_index :call_logs, :created_at
  end
end
