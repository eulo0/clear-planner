class AddCanvasFieldsToCourseItems < ActiveRecord::Migration[8.1]
  def change
    add_column :course_items, :canvas_uid, :string
    add_column :course_items, :source, :integer, default: 0, null: false

    add_index :course_items, [ :course_id, :canvas_uid ],
              unique: true,
              where: "canvas_uid IS NOT NULL",
              name: "index_course_items_on_course_and_canvas_uid"
  end
end
