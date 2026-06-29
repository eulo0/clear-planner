# frozen_string_literal: true

class Block < ApplicationRecord
  belongs_to :user

  STATUSES = %w[proposed active disabled].freeze

  Occurrence = Struct.new(:event, :starts_at, :ends_at, :draft_status, keyword_init: true)

  validates :label, presence: true
  validates :start_minute, :end_minute, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate  :end_after_start
  validate  :within_day
  validate  :repeat_days_are_valid_weekdays

  scope :active,   -> { where(status: "active") }
  scope :proposed, -> { where(status: "proposed") }

  # Project this recurring time-of-day window onto every matching weekday in the range.
  def occurrences_between(range_start, range_end)
    return [] if start_minute.blank? || end_minute.blank?
    days = Array(repeat_days).map(&:to_i)
    return [] if days.empty?

    result = []
    date = range_start.to_date
    while date <= range_end.to_date
      if days.include?(date.wday)
        starts = Time.zone.local(date.year, date.month, date.day) + start_minute.minutes
        ends   = Time.zone.local(date.year, date.month, date.day) + end_minute.minutes
        result << Occurrence.new(event: self, starts_at: starts, ends_at: ends) if starts <= range_end && ends >= range_start
      end
      date += 1
    end
    result
  end

  private

  def end_after_start
    return if start_minute.blank? || end_minute.blank?
    errors.add(:end_minute, "must be after start") if end_minute.to_i <= start_minute.to_i
  end

  def within_day
    return if start_minute.blank? || end_minute.blank?
    unless start_minute.to_i >= 0 && start_minute.to_i < 24 * 60 &&
           end_minute.to_i > 0 && end_minute.to_i <= 24 * 60
      errors.add(:base, "block must be inside one day")
    end
  end

  def repeat_days_are_valid_weekdays
    invalid = Array(repeat_days).reject { |d| d.is_a?(Integer) && d.between?(0, 6) }
    errors.add(:repeat_days, "contains invalid weekday values") if invalid.any?
  end
end
