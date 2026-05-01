class AddGradeWeightsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :grade_weights, :jsonb, default: {}, null: false
  end
end
