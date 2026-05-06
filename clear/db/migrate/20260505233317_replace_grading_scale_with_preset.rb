class ReplaceGradingScaleWithPreset < ActiveRecord::Migration[8.1]
  def change
    remove_column :courses, :grading_scale, :jsonb
    add_column :courses, :grading_scale_preset, :string, default: "ten_point", null: false
  end
end
