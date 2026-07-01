class AddColorToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :color, :string
  end
end
