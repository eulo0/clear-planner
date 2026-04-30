class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum :role, { viewer: 1, editor: 2, owner: 3 }

  def can_manage_members?
    owner?
  end

  def can_edit_content?
    editor? || owner?
  end

  def can_manage_project?
    owner?
  end
end
