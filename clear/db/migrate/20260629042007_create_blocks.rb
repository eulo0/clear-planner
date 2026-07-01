class CreateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :blocks do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :label,        null: false
      t.string  :color,        null: false, default: "#6366f1"
      t.integer :repeat_days,  null: false, default: [], array: true
      t.integer :start_minute, null: false
      t.integer :end_minute,   null: false
      t.string  :status,       null: false, default: "active"
      t.integer :position,     null: false, default: 0
      t.timestamps
    end
    add_index :blocks, [ :user_id, :status ]
  end
end
