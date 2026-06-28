# frozen_string_literal: true

class Task < ApplicationRecord
  belongs_to :user
  belongs_to :course_item, optional: true

  validates :title, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validate :course_item_belongs_to_user, if: -> { course_item.present? }

  scope :scheduled, -> { where.not(scheduled_at: nil) }
  scope :unscheduled, -> { where(scheduled_at: nil) }
  scope :incomplete, -> { where(done: false) }

  def scheduled? = scheduled_at.present?

  private

  def course_item_belongs_to_user
    return if course_item.course&.user_id == user_id
    errors.add(:course_item, "must belong to you")
  end
end
