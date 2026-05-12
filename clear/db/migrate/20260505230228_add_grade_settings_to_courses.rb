class AddGradeSettingsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :grade_calculation, :string, default: "points", null: false
    add_column :courses, :grading_scale,     :jsonb,  default: {},       null: false
  end
end
