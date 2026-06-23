# frozen_string_literal: true

class EventException < ApplicationRecord
  belongs_to :event

  validates :excluded_date, presence: true,
                            uniqueness: { scope: :event_id }

  # A row may optionally relocate the suppressed occurrence to a new time
  # (Option B override). If it does, both ends of the override must be present
  # and ordered.
  validate :override_times_paired_and_ordered

  def override?
    override_starts_at.present?
  end

  private

  def override_times_paired_and_ordered
    return if override_starts_at.blank? && override_ends_at.blank?

    if override_starts_at.blank?
      errors.add(:override_starts_at, "must be set when override_ends_at is set")
    elsif override_ends_at.blank?
      errors.add(:override_ends_at, "must be set when override_starts_at is set")
    elsif override_ends_at < override_starts_at
      errors.add(:override_ends_at, "must be on/after the override start time")
    end
  end
end
