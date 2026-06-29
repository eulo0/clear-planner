# frozen_string_literal: true

class Event < ApplicationRecord
  include Colorable

  belongs_to :user
  belongs_to :project, optional: true
  has_many :event_exceptions, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  attr_accessor :auto_schedule

  def auto_schedule?
    ActiveModel::Type::Boolean.new.cast(auto_schedule)
  end

  validates :title, presence: true
  validates :starts_at, presence: true
  validate :ends_at_after_starts_at, if: -> { starts_at.present? && ends_at.present? }

  validates :color,
            format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #34D399" },
            allow_nil: true

  validates :repeat_until, presence: true, if: :recurring?
  validate :repeat_days_present_if_recurring
  validate :repeat_days_are_valid_weekdays
  validate :repeat_until_not_before_start, if: -> { recurring? && repeat_until.present? && starts_at.present? }

  before_validation :derive_ends_at_from_duration
  before_validation :normalize_recurrence_fields
  before_validation :normalize_color

  after_create_commit :create_notification

  # override_date is the rule date a relocated (Option B override) occurrence was
  # moved FROM — i.e. the exception's excluded_date. It is the stable key a
  # re-drag uses to update the same override row instead of creating a new one.
  # nil for ordinary rule-generated occurrences.
  Occurrence = Struct.new(:event, :starts_at, :ends_at, :draft_status, :override_date, keyword_init: true) do
    delegate :id, :title, :location, :description, :color, :contrast_text_color, to: :event
  end

  def occurrences_between(range_start, range_end)
    unless recurring?
      return [] if starts_at.nil? || starts_at < range_start || starts_at > range_end
      return [ Occurrence.new(event: self, starts_at: starts_at, ends_at: ends_at) ]
    end

    start_time = starts_at.in_time_zone
    duration = ends_at.present? ? (ends_at.in_time_zone - start_time) : nil

    out = []

    # Pass 1 — rule-generated occurrences, suppressing any date that carries an
    # exception (whether a plain exclusion or a relocated/override row; both mean
    # "the rule's occurrence on this date does not appear in its original slot").
    window_start_date = [ range_start.to_date, starts_at.to_date ].max
    window_end_date   = [ range_end.to_date, repeat_until ].min

    if window_end_date >= window_start_date
      excluded = event_exceptions.where(excluded_date: window_start_date..window_end_date)
                                 .pluck(:excluded_date).to_set
      d = window_start_date
      while d <= window_end_date
        if repeat_days.include?(d.wday) && !excluded.include?(d)
          occ_start = Time.zone.local(d.year, d.month, d.day, start_time.hour, start_time.min, start_time.sec)
          occ_end   = duration.present? ? (occ_start + duration) : nil
          out << Occurrence.new(event: self, starts_at: occ_start, ends_at: occ_end)
        end
        d += 1.day
      end
    end

    # Pass 2 — relocated occurrences (Option B override rows) whose new start
    # lands inside the queried range. The new slot may fall on a weekday outside
    # repeat_days, or even past repeat_until, so this is independent of Pass 1's
    # rule window.
    event_exceptions.where(override_starts_at: range_start..range_end).find_each do |ex|
      out << Occurrence.new(event: self, starts_at: ex.override_starts_at, ends_at: ex.override_ends_at,
                            override_date: ex.excluded_date)
    end

    out.sort_by(&:starts_at)
  end

  private

  def derive_ends_at_from_duration
    return if ends_at.present? || starts_at.blank? || duration_minutes.blank?
    self.ends_at = starts_at + duration_minutes.minutes
  end

  def ends_at_after_starts_at
    return if ends_at >= starts_at
    errors.add(:ends_at, "must be after the start time")
  end

  def normalize_recurrence_fields
    self.repeat_days = Array(repeat_days).reject(&:blank?).map(&:to_i).uniq.sort

    unless recurring?
      self.repeat_days = []
      self.repeat_until = nil
    end
  end

  def normalize_color
    self.color = color.to_s.strip.upcase
    self.color = "#34D399" if color.blank?
  end

  def repeat_days_present_if_recurring
    return unless recurring?
    errors.add(:repeat_days, "pick at least one day") if repeat_days.blank?
  end

  def repeat_days_are_valid_weekdays
    return if repeat_days.blank?
    invalid = repeat_days.reject { |d| d.is_a?(Integer) && d.between?(0, 6) }
    errors.add(:repeat_days, "contains invalid weekday values") if invalid.any?
  end

  def repeat_until_not_before_start
    return if repeat_until >= starts_at.to_date
    errors.add(:repeat_until, "must be on/after the start date")
  end

  def create_notification
    base_message = starts_at ? "#{title} at #{starts_at.strftime("%-b %-d at %-I:%M %p")}" : title
    category     = (priority.present? && priority > 0) ? "high_priority" : "event_created"

    creator_message = project.present? ? %(#{base_message} in group "#{project.title}") : base_message

    Notification.create!(
      user: user,
      notifiable: self,
      category: category,
      message: creator_message
    )

    return unless project.present?

    creator_name = user.username.presence || user.email
    project.users.where.not(id: user.id).find_each do |member|
      Notification.create!(
        user: member,
        notifiable: self,
        category: category,
        message: %(#{creator_name} added #{base_message} in group "#{project.title}")
      )
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "all_day", "color", "created_at", "description", "duration_minutes", "ends_at", "location", "recurring", "repeat_days", "repeat_until", "starts_at", "title", "updated_at" ]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
