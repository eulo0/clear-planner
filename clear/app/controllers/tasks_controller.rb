# frozen_string_literal: true

class TasksController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!

  # Static mockup of the v2 Tasks page ("Plan" tab). No Task model exists yet —
  # all data below is hardcoded sample data, shaped to mirror the eventual models
  # so swapping in live data later is a localized change (replace the builders).
  #
  # Eventual shapes this mirrors:
  #   course        -> { code, name, color }
  #   course_item   -> { title, type, due, overdue }  (the deadline)
  #   task          -> { title, estimate_minutes, scheduled (string|nil), done, overdue }
  #   ai suggestion -> { title, estimate_minutes }    (proposed task, not yet created)
  def index
    @courses = sample_courses
    @groups  = sample_groups

    # Assign a stable id to every task so the same task can render across the
    # List / Breakdown / Missed panes and have its completion toggle stay in
    # sync client-side (one [data-task-id], many occurrences).
    idc = 0
    @groups.each { |g| g[:tasks].each { |task| idc += 1; task[:id] = "t#{idc}" } }

    # Flat task list for the List view, each task carrying its course context.
    @all_tasks = @groups.flat_map do |g|
      g[:tasks].map { |task| task.merge(course: g[:course], personal: g[:personal]) }
    end

    # Missed = tasks whose linked course item's due date has passed (group
    # overdue) and that aren't done. Personal/deadline-less tasks never qualify.
    # We carry done tasks too (rendered hidden) so the live toggle can hide/show.
    @missed_tasks = @groups.flat_map do |g|
      next [] unless g[:overdue] && !g[:personal]

      late = g[:due_on] ? (Date.current - g[:due_on]).to_i : nil
      g[:tasks].map { |task| task.merge(course: g[:course], due: g[:due], overdue: true, late_days: late) }
    end

    @counts = {
      list:      @all_tasks.size,
      breakdown: @groups.count { |g| !g[:personal] },
      missed:    @missed_tasks.count { |task| !task[:done] }
    }
  end

  private

  def sample_courses
    [
      { id: "cw", code: "MTG 410",  name: "Creative Writing",  color: "#60a5fa" },
      { id: "qm", code: "PHYS 330", name: "Quantum Mechanics", color: "#a78bfa" },
      { id: "st", code: "STAT 250", name: "Statistics",        color: "#f59e0b" }
    ]
  end

  # Task type → badge colors (course-item kind).
  def type_style(type)
    {
      "Assignment" => { bg: "rgba(96,165,250,.14)", bd: "rgba(96,165,250,.4)", fg: "#bfdbfe" },
      "Exam"       => { bg: "rgba(244,63,94,.14)",  bd: "rgba(244,63,94,.4)",  fg: "#fda4af" },
      "Reading"    => { bg: "rgba(52,211,153,.14)", bd: "rgba(52,211,153,.4)", fg: "#a7f3d0" },
      "Project"    => { bg: "rgba(245,158,11,.14)", bd: "rgba(245,158,11,.4)", fg: "#fcd34d" },
      "Workshop"   => { bg: "rgba(167,139,250,.14)", bd: "rgba(167,139,250,.4)", fg: "#ddd6fe" }
    }[type] || { bg: "var(--studs-panel-bg-2)", bd: "var(--studs-border)", fg: "#a1a1aa" }
  end

  def t(title, est, scheduled, done: false, overdue: false, today: false)
    { title: title, estimate: est, scheduled: scheduled, done: done, overdue: overdue, today: today }
  end

  # Each group = one course item (deadline) and its tasks, plus a trailing
  # "Personal" group for tasks not tied to a course.
  def sample_groups
    cw = sample_courses[0]
    qm = sample_courses[1]
    st = sample_courses[2]

    [
      group(
        title: "Reading Response 4", type: "Reading", course: cw, due_on: Date.current - 3,
        overdue: true, broken_down: false, suggestions: [],
        tasks: [
          t("Read the assigned chapters", 35, nil),
          t("Write the one-page response", 40, nil)
        ]
      ),
      group(
        title: "Lab Report 2", type: "Project", course: st, due_on: Date.current - 2,
        overdue: true, broken_down: false, suggestions: [],
        tasks: [
          t("Finish the results section", 50, nil)
        ]
      ),
      group(
        title: "Final Portfolio", type: "Assignment", course: cw, due: "Sep 16",
        broken_down: false, suggestions: [],
        tasks: [
          t("Outline the three pieces", 45, "Tue · 2:00 PM", today: true),
          t("Revise the short story",   90, "Thu · 10:00 AM", done: true),
          t("Write the cover essay",    60, nil)
        ]
      ),
      group(
        title: "Problem Set 5", type: "Assignment", course: qm, due: "Jul 2",
        broken_down: true,
        suggestions: [ { title: "Review solutions before submitting", estimate: 25 } ],
        tasks: [
          t("Read Ch. 4 lecture notes", 40, "Tue · 4:00 PM", today: true),
          t("Solve problems 1–6",       75, nil)
        ]
      ),
      group(
        title: "Data Project", type: "Project", course: st, due: "Jul 7",
        broken_down: false, suggestions: [ { title: "Draft the write-up", estimate: 40 } ],
        tasks: [
          t("Clean the dataset", 50, "Tue · 6:30 PM", today: true),
          t("Build the charts",  60, nil),
          t("Run the regression", 45, nil)
        ]
      ),
      group(
        title: "Midterm Exam", type: "Exam", course: qm, due: "Jun 30",
        broken_down: false,
        suggestions: [
          { title: "Make a one-page formula sheet", estimate: 30 },
          { title: "Take a timed practice exam",     estimate: 90 }
        ],
        tasks: []
      ),
      {
        personal: true, title: "Personal to-dos", type: nil, course: nil,
        due: nil, overdue: false, broken_down: false, suggestions: [],
        tasks: [ t("Renew library books", 15, nil) ],
        type_style: nil,
        progress: progress_for([ t("Renew library books", 15, nil) ])
      }
    ]
  end

  # due_on (a real Date) drives the "days late" math for the Missed view; when
  # given it also derives the human due label so the card and Missed agree.
  def group(title:, type:, course:, tasks:, broken_down:, suggestions:, due: nil, due_on: nil, overdue: false)
    {
      personal: false, title: title, type: type, type_style: type_style(type),
      course: course, due: due || due_on&.strftime("%b %-d"), due_on: due_on, overdue: overdue,
      broken_down: broken_down, suggestions: suggestions, tasks: tasks,
      progress: progress_for(tasks)
    }
  end

  def progress_for(tasks)
    total = tasks.size
    done  = tasks.count { |x| x[:done] }
    { done: done, total: total, pct: total.zero? ? 0 : (done.to_f / total * 100).round }
  end
  helper_method :type_style
end
