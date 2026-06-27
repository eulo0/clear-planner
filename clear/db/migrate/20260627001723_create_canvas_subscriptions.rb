class CreateCanvasSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :canvas_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :feed_url, null: false
      t.string :status, null: false, default: "idle"
      t.datetime :last_synced_at
      t.text :last_error
      t.jsonb :last_summary
      t.timestamps
    end
  end
end
