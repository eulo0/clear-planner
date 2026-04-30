class AddRoleToProjectMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :project_memberships, :role, :integer, default: 1, null: false
  end
end
