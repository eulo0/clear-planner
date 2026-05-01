class AddGradeFieldsToCourseItems < ActiveRecord::Migration[8.1]
  def change
    add_column :course_items, :points_possible, :decimal
    add_column :course_items, :points_earned, :decimal
  end
end
