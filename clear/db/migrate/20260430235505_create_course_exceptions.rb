class CreateCourseExceptions < ActiveRecord::Migration[8.1]
  def change
    create_table :course_exceptions do |t|
      t.references :course, null: false, foreign_key: true
      t.date :excluded_date, null: false

      t.timestamps
    end

    add_index :course_exceptions, [ :course_id, :excluded_date ], unique: true
  end
end
