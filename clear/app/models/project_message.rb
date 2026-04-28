class ProjectMessage < ApplicationRecord
  RETAIN_FOR = 24.hours

  belongs_to :user
  belongs_to :project
  has_many :project_messages, dependent: :destroy

  validates :body, presence: true

  broadcasts_to ->(message) { [ message.project, :project_messages ] }, inserts_at: :bottom

  after_create :prune_old_messages

  private

  def prune_old_messages
    project.project_messages.where("created_at < ?", RETAIN_FOR.ago).delete_all
  end
end
