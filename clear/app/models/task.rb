# frozen_string_literal: true

class Task < ApplicationRecord
  include Colorable

  belongs_to :user
  belongs_to :course_item, optional: true

  validates :title, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validate :course_item_belongs_to_user, if: -> { course_item.present? }
  validates :color,
            format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #34D399" },
            allow_nil: true

  before_validation :set_default_color

  # One block on the calendar: scheduled_at → scheduled_at + duration.
  # Mirrors Event::Occurrence's interface (see app/models/event.rb:38).
  Occurrence = Struct.new(:event, :starts_at, :ends_at, :draft_status, keyword_init: true) do
    delegate :id, :title, :location, :description, :color, :contrast_text_color, to: :event
  end

  scope :scheduled, -> { where.not(scheduled_at: nil) }
  scope :unscheduled, -> { where(scheduled_at: nil) }
  scope :incomplete, -> { where(done: false) }

  def scheduled? = scheduled_at.present?

  # Tasks have no location concept; satisfies the occurrence interface.
  def location = nil

  def occurrences_between(range_start, range_end)
    return [] unless scheduled_at

    starts = scheduled_at
    ends   = scheduled_at + duration_minutes.minutes
    # Span-overlap: include task if any part of its block falls in range.
    return [] unless starts <= range_end && ends >= range_start

    [ Occurrence.new(event: self, starts_at: starts, ends_at: ends) ]
  end

  private

  def set_default_color
    self.color ||= course_item&.course&.color || "#34D399"
  end

  def course_item_belongs_to_user
    return if course_item.course&.user_id == user_id
    errors.add(:course_item, "must belong to you")
  end
end
