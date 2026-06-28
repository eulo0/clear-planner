class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course_item, null: true, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.text :description
      t.datetime :scheduled_at
      t.integer :duration_minutes, null: false
      t.boolean :done, null: false, default: false
      t.datetime :completed_at
      t.timestamps
    end

    add_index :tasks, [ :user_id, :scheduled_at ]
  end
end
