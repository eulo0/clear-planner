class AddOnboardStatusToUsers < ActiveRecord::Migration[8.1]
  def up
    # New signups should land in the syllabus onboarding flow, so the column
    # defaults to true. Existing accounts are grandfathered out (set to false)
    # so shipping this never interrupts a current user mid-session.
    add_column :users, :onboard_status, :boolean, default: true, null: false
    execute("UPDATE users SET onboard_status = FALSE")
  end

  def down
    remove_column :users, :onboard_status
  end
end
