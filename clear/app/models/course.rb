# frozen_string_literal: true

class Course < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true
  has_many :course_items, dependent: :destroy
  has_many :syllabuses, dependent: :nullify
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :course_exceptions, dependent: :destroy

  validates :title, presence: true
  validates :start_time, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  # Ensure the meeting time window makes sense
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  # Ensure the course end date is not before the start date
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

  # This lets us visually distinguish courses later in the UI or calendar.
  validates :color,
            format: {
              with: /\A#[0-9a-fA-F]{6}\z/,
              message: "must be a hex color like #34D399"
            },
            allow_nil: true

  after_create_commit :create_notification

  # Normalize fields before validation
  before_validation :derive_end_time_from_duration
  before_validation :normalize_color
  before_validation :normalize_meeting_days
  before_validation :sync_repeat_days_from_meeting_days
  before_validation :normalize_repeat_days
  before_validation :force_recurrence_defaults

  # Courses are inherently recurring in our app
  validate :repeat_days_present
  validate :repeat_days_are_valid_weekdays

  # Used by the dashboard calendar
  Occurrence = Struct.new(:event, :starts_at, :ends_at, :draft_status, keyword_init: true) do
    delegate :id, :title, :location, :description, :color, :contrast_text_color, to: :event
  end

  def next_occurrence_at(from: Time.current)
    from_date = [ from.to_date, start_date ].max
    d = from_date
    while d <= end_date
      if repeat_days.include?(d.wday)
        return Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, 0)
      end
      d += 1.day
    end
    nil
  end

  # Generate course occurrences within the given date range
  def occurrences_between(range_start, range_end)
    return [] if start_date.blank? || end_date.blank? || repeat_days.blank? || start_time.blank?

    window_start = [ range_start.to_date, start_date ].max
    window_end   = [ range_end.to_date, end_date ].min
    return [] if window_end < window_start

    excluded_dates = course_exceptions.map(&:excluded_date).to_set

    out = []
    d = window_start
    while d <= window_end
      if repeat_days.include?(d.wday) && !excluded_dates.include?(d)
        occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)

        occ_end =
          if end_time.present?
            Time.zone.local(d.year, d.month, d.day, end_time.hour, end_time.min, end_time.sec)
          end

        out << Occurrence.new(event: self, starts_at: occ_start, ends_at: occ_end)
      end
      d += 1.day
    end
    out
  end

  def overall_grade
    kinds_with_weight = grade_weights.select { |_, w| w.to_f > 0 }
    return nil if kinds_with_weight.empty?

    graded_items = course_items.select(&:graded?)
    return nil if graded_items.empty?

    weighted_sum = 0.0
    total_weight = 0.0

    kinds_with_weight.each do |kind, weight|
      items = graded_items.select { |i| i.kind == kind }
      next if items.empty?

      avg = items.sum { |i| i.points_earned.to_f / i.points_possible.to_f } / items.size
      weighted_sum += weight.to_f * avg
      total_weight += weight.to_f
    end

    return nil if total_weight.zero?

    (weighted_sum / total_weight * 100).round(1)
  end

  def letter_grade(percentage)
    case percentage
    when 90..Float::INFINITY then "A"
    when 80...90 then "B"
    when 70...80 then "C"
    when 60...70 then "D"
    else "F"
    end
  end

  # Text color for calendar readability
  def contrast_text_color
    hex = color.to_s.delete("#")
    return "#0A0A0A" unless hex.length == 6

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    luminance = (0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b))
    luminance > 0.55 ? "#0A0A0A" : "#F9FAFB"
  end

  private

  def create_notification
    base_message    = start_time ? "#{title} at #{start_time.strftime("%-I:%M %p")}" : title
    creator_message = project.present? ? %(#{base_message} in group "#{project.title}") : base_message

    Notification.create!(
      user: user,
      notifiable: self,
      category: "course_added",
      message: creator_message
    )

    return unless project.present?

    creator_name = user.username.presence || user.email
    project.users.where.not(id: user.id).find_each do |member|
      Notification.create!(
        user: member,
        notifiable: self,
        category: "course_added",
        message: %(#{creator_name} added #{base_message} in group "#{project.title}")
      )
    end
  end

  def derive_end_time_from_duration
    return if end_time.present? || start_time.blank? || duration_minutes.blank?
    self.end_time = start_time + duration_minutes.minutes
  end

  # Courses are always recurring in our app
  def force_recurrence_defaults
    self.recurring = true
    self.repeat_until = end_date if end_date.present?
  end

  def normalize_color
    self.color = color.to_s.strip.upcase
    self.color = "#34D399" if color.blank?
  end

  def normalize_meeting_days
    self.meeting_days = meeting_days.to_s.upcase.gsub(/[^MTWRF]/, "").presence
  end

  def sync_repeat_days_from_meeting_days
    return if meeting_days.blank?

    map = {
      "M" => 1,
      "T" => 2,
      "W" => 3,
      "R" => 4,
      "F" => 5
    }

    self.repeat_days = meeting_days.chars.filter_map { |ch| map[ch] }
  end

  def normalize_repeat_days
    self.repeat_days =
      Array(repeat_days)
        .reject(&:blank?)
        .map(&:to_i)
        .uniq
        .sort
  end

  def repeat_days_present
    errors.add(:repeat_days, "pick at least one day") if repeat_days.blank?
  end

  def repeat_days_are_valid_weekdays
    return if repeat_days.blank?

    invalid = repeat_days.reject { |d| d.is_a?(Integer) && d.between?(0, 6) }
    errors.add(:repeat_days, "contains invalid weekday values") if invalid.any?
  end

  def end_time_after_start_time
    return if end_time >= start_time
    errors.add(:end_time, "must be after the start time")
  end

  def end_date_after_start_date
    return if end_date >= start_date
    errors.add(:end_date, "must be after the start date")
  end

  def srgb_linear(channel)
    c = channel / 255.0
    c <= 0.03928 ? (c / 12.92) : (((c + 0.055) / 1.055)**2.4)
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "code", "color", "created_at", "description", "duration_minutes", "end_date", "end_time", "instructor", "location", "meeting_days", "office", "office_hours", "professor", "recurring", "repeat_days", "repeat_until", "start_date", "start_time", "term", "title", "updated_at" ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
