class UpdateCalendarDraftsForMultiDraft < ActiveRecord::Migration[8.1]
  def up
    add_column :calendar_drafts, :name, :string
    remove_index :calendar_drafts, name: "index_calendar_drafts_on_user_id", if_exists: true
    add_index :calendar_drafts, :user_id, name: "index_calendar_drafts_on_user_id"
    execute <<~SQL
      UPDATE calendar_drafts
      SET name = 'First Draft'
      WHERE name IS NULL
    SQL
    change_column_null :calendar_drafts, :name, false
  end

  def down
    remove_column :calendar_drafts, :name if column_exists?(:calendar_drafts, :name)
    remove_index :calendar_drafts, name: "index_calendar_drafts_on_user_id" if exists :true
    add_index :calendar_drafts, :user_id, unique: true, name: "index_calendar_drafts_on_user_id" unless index_exists?(:calendar_drafts, :user_id, unique: true, name: "index_calendar_drafts_on_user_id")
  end
end
