# frozen_string_literal: true

class CourseItem < ApplicationRecord
  belongs_to :course
  has_many :notifications, as: :notifiable, dependent: :destroy

  enum :kind, {
    assignment: 0,
    quiz: 1,
    exam: 2,
    project: 3,
    reading: 4,
    lab: 5,
    presentation: 6,
    seminar: 7,
    other: 8
  }

  enum :source, { manual: 0, syllabus: 1, canvas: 2 }, prefix: :source

  thread_mattr_accessor :suppress_sync_notifications, instance_accessor: false, default: false

  def self.suppressing_sync_notifications
    previous = suppress_sync_notifications
    self.suppress_sync_notifications = true
    yield
  ensure
    self.suppress_sync_notifications = previous
  end

  validates :title, presence: true
  validates :kind, presence: true
  validates :points_possible, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :points_earned, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  after_create_commit :create_assignment_notification,
                      unless: -> { CourseItem.suppress_sync_notifications }

  def display_title
    course_name = course&.title.presence || "Course"
    kind_name   = kind.present? ? kind.humanize : "Item"
    base        = self[:title].presence

    base ? "#{course_name} — #{kind_name}: #{base}" : "#{course_name} — #{kind_name}"
  end

  private

  def create_assignment_notification
    base_message    = due_at ? "#{title} due: #{due_at.strftime("%-b %-d at %-I:%M %p")}" : "#{title} due: No date set"
    project         = course.project
    creator_message = project.present? ? %(#{base_message} in group "#{project.title}") : base_message

    Notification.create!(
      user: course.user,
      notifiable: self,
      category: "assignment_due",
      message: creator_message
    )

    return unless project.present?

    creator_name = course.user.username.presence || course.user.email
    project.users.where.not(id: course.user_id).find_each do |member|
      Notification.create!(
        user: member,
        notifiable: self,
        category: "assignment_due",
        message: %(#{creator_name} added #{base_message} in group "#{project.title}")
      )
    end
  end

  public

  def graded? = points_possible.present? && points_possible > 0 && points_earned.present?

  def grade_percentage
    return nil unless graded?
    (points_earned / points_possible * 100).round(1)
  end

  def starts_at = due_at
  def ends_at = due_at ? due_at + 30.minutes : nil
  def color = course.color

  def contrast_text_color
    course.respond_to?(:contrast_text_color) ? course.contrast_text_color : "#F9FAFB"
  end
end
