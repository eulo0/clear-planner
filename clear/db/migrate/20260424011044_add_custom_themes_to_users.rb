class AddCustomThemesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :custom_themes, :jsonb, default: {}
  end
end
