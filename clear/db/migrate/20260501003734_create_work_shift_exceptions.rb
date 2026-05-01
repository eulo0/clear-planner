class CreateWorkShiftExceptions < ActiveRecord::Migration[8.1]
  def change
    create_table :work_shift_exceptions do |t|
      t.references :work_shift, null: false, foreign_key: true
      t.date :excluded_date, null: false

      t.timestamps
    end
    add_index :work_shift_exceptions, [ :work_shift_id, :excluded_date ], unique: true
  end
end
