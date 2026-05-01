# frozen_string_literal: true

class CheckUpcomingRemindersJob < ApplicationJob
  queue_as :default

  REMINDER_WINDOW_MIN = 55.minutes
  REMINDER_WINDOW_MAX = 65.minutes
  ASSIGNMENT_WINDOW_MIN = 23.hours + 55.minutes
  ASSIGNMENT_WINDOW_MAX = 24.hours + 5.minutes

  def perform
    remind_for_events
    remind_for_courses
    remind_for_course_items
  end

  private

  def remind_for_events
    window_start = REMINDER_WINDOW_MIN.from_now
    window_end   = REMINDER_WINDOW_MAX.from_now

    Event.includes(:user, :event_exceptions).find_each do |event|
      event.occurrences_between(window_start, window_end).each do |occ|
        next unless occ.starts_at.between?(window_start, window_end)

        create_reminder(
          user: event.user,
          notifiable: event,
          category: "event_reminder",
          scheduled_for: occ.starts_at,
          message: "Event starting soon: #{event.title} at #{occ.starts_at.strftime("%-I:%M %p")}"
        )
      end
    end
  end

  def remind_for_courses
    window_start = REMINDER_WINDOW_MIN.from_now
    window_end   = REMINDER_WINDOW_MAX.from_now

    Course.includes(:user, course_exceptions).find_each do |course|
      course.occurrences_between(window_start, window_end).each do |occ|
        next unless occ.starts_at.between?(window_start, window_end)

        create_reminder(
          user: course.user,
          notifiable: course,
          category: "course_reminder",
          scheduled_for: occ.starts_at,
          message: "Course starting soon: #{course.title} at #{occ.starts_at.strftime("%-I:%M %p")}"
        )
      end
    end
  end

  def remind_for_course_items
    window_start = ASSIGNMENT_WINDOW_MIN.from_now
    window_end   = ASSIGNMENT_WINDOW_MAX.from_now

    CourseItem.includes(course: :user).where(due_at: window_start..window_end).find_each do |item|
      create_reminder(
        user: item.course.user,
        notifiable: item,
        category: "assignment_reminder",
        scheduled_for: item.due_at,
        message: "#{item.kind.humanize} due: #{item.title} at #{item.due_at.strftime("%-I:%M %p")}"
      )
    end
  end

  def create_reminder(user:, notifiable:, category:, scheduled_for:, message:)
    Notification.find_or_create_by!(
      user: user,
      notifiable: notifiable,
      category: category,
      scheduled_for: scheduled_for
    ) do |n|
      n.message = message
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.warn("CheckUpcomingRemindersJob: skipped duplicate — #{e.message}")
  end
end
