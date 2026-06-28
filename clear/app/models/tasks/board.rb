# frozen_string_literal: true

module Tasks
  class Board
    Result = Struct.new(:courses, :groups, :all_tasks, :missed_tasks, :counts, keyword_init: true)

    TYPE_STYLES = {
      "Assignment" => { bg: "rgba(96,165,250,.14)", bd: "rgba(96,165,250,.4)", fg: "#bfdbfe" },
      "Exam"       => { bg: "rgba(244,63,94,.14)",  bd: "rgba(244,63,94,.4)",  fg: "#fda4af" },
      "Reading"    => { bg: "rgba(52,211,153,.14)", bd: "rgba(52,211,153,.4)", fg: "#a7f3d0" },
      "Project"    => { bg: "rgba(245,158,11,.14)", bd: "rgba(245,158,11,.4)", fg: "#fcd34d" }
    }.freeze
    DEFAULT_STYLE = { bg: "var(--studs-panel-bg-2)", bd: "var(--studs-border)", fg: "#a1a1aa" }.freeze

    def initialize(user, q: nil, status: nil, course_id: nil)
      @user = user
      @q = q.to_s.strip
      @status = status.to_s
      @course_id = course_id.presence
    end

    def call
      scope = base_scope.to_a
      groups = build_groups(scope)
      list = filter_status(build_all_tasks(scope))
      missed = build_missed(scope)

      Result.new(
        courses: course_options,
        groups: groups,
        all_tasks: list,
        missed_tasks: missed,
        counts: {
          list: list.size,
          breakdown: groups.count { |g| !g[:personal] },
          missed: missed.count { |t| !t[:done] }
        }
      )
    end

    private

    attr_reader :user, :q, :status, :course_id

    def base_scope
      scope = user.tasks.includes(course_item: :course)
      scope = scope.where("tasks.title ILIKE ?", "%#{q}%") if q.present?
      if course_id.present?
        scope = scope.joins(course_item: :course).where(course_items: { course_id: course_id })
      end
      scope.order(:created_at)
    end

    def filter_status(tasks)
      case status
      when "scheduled"   then tasks.select { |t| t[:scheduled].present? }
      when "unscheduled" then tasks.reject { |t| t[:scheduled].present? }
      else tasks
      end
    end

    def build_all_tasks(scope)
      scope.map do |task|
        item = task.course_item
        task_hash(task).merge(
          personal: item.nil?,
          course: item && course_hash(item.course)
        )
      end
    end

    def build_groups(scope)
      linked, personal = scope.partition { |t| t.course_item_id.present? }

      groups = linked.group_by(&:course_item).map do |item, tasks|
        type = item.kind.to_s.humanize
        course = item.course
        overdue = item.due_at.present? && item.due_at.to_date < Date.current
        {
          personal: false,
          title: item.title,
          type: type,
          type_style: TYPE_STYLES.fetch(type, DEFAULT_STYLE),
          course: course_hash(course),
          overdue: overdue,
          due: item.due_at&.strftime("%b %-d"),
          progress: progress_for(tasks),
          broken_down: false,
          suggestions: [],
          tasks: tasks.map { |t| task_hash(t) }
        }
      end

      unless personal.empty?
        groups << {
          personal: true, title: "Personal to-dos", type: nil, type_style: nil,
          course: nil, overdue: false, due: nil,
          progress: progress_for(personal), broken_down: false, suggestions: [],
          tasks: personal.map { |t| task_hash(t) }
        }
      end

      groups
    end

    def build_missed(scope)
      scope.select { |t| missed?(t) }.map do |task|
        item = task.course_item
        anchor = item&.due_at || task.scheduled_at
        task_hash(task).merge(
          personal: item.nil?,
          course: item && course_hash(item.course),
          due: anchor&.strftime("%b %-d"),
          overdue: true,
          late_days: anchor ? (Date.current - anchor.to_date).to_i : nil
        )
      end
    end

    def missed?(task)
      item = task.course_item
      past_deadline = item&.due_at.present? && item.due_at.to_date < Date.current
      past_scheduled = task.scheduled_at.present? && task.scheduled_at < Time.current
      past_deadline || past_scheduled
    end

    def task_hash(task)
      {
        id: task.id.to_s,
        title: task.title,
        estimate: task.duration_minutes,
        scheduled: task.scheduled_at&.strftime("%a · %-I:%M %p"),
        done: task.done
      }
    end

    def course_hash(course)
      { id: course.id, code: course.code, name: course.title, color: course.color.to_s.downcase }
    end

    def course_options
      user.courses.order(:title).map { |c| course_hash(c) }
    end

    def progress_for(tasks)
      total = tasks.size
      done = tasks.count(&:done)
      { done: done, total: total, pct: total.zero? ? 0 : (done.to_f / total * 100).round }
    end
  end
end
