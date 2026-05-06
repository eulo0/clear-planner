class ProjectInvitation < ApplicationRecord
  belongs_to :project
  belongs_to :sender, class_name: "User"

  before_create :generate_token

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :project_id, conditions: -> { where(accepted_at: nil) },
                                  message: "has already been invited to this project" }

  scope :pending, -> { where(accepted_at: nil) }

  def accepted?
    accepted_at.present?
  end

  def accept!(user)
    return if accepted?

    already_member = project.users.include?(user)

    transaction do
      update!(accepted_at: Time.current)
      project.users << user unless already_member
    end

    project.notify_member_joined(user) unless already_member
  end

  private

  def generate_token
    self.token = SecureRandom.hex(16)
  end
end
