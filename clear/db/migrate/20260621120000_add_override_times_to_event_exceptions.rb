# frozen_string_literal: true

class AddOverrideTimesToEventExceptions < ActiveRecord::Migration[8.1]
  def change
    add_column :event_exceptions, :override_starts_at, :datetime
    add_column :event_exceptions, :override_ends_at, :datetime
  end
end
