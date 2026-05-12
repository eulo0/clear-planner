class RemoveGradingScalePresetFromCourses < ActiveRecord::Migration[8.1]
  def change
    remove_column :courses, :grading_scale_preset, :string
  end
end
