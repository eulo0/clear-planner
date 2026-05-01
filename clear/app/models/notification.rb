# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  CATEGORIES = %w[assignment_due high_priority event_created course_added group group_member_joined event_reminder course_reminder assignment_reminder].freeze

  validates :category, inclusion: { in: CATEGORIES }

  scope :unread,  -> { where(read_at: nil) }
  scope :read,    -> { where.not(read_at: nil) }
  scope :recent,  -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
