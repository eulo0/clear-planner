# db/seeds.rb
require "securerandom"

puts "seeding..."

# ----------------------------
# Admin seed (ALL environments)
# ----------------------------
ADMIN_EMAIL = ENV.fetch("ADMIN_EMAIL", "admin@clearplanner.app")

admin_password =
  if Rails.env.production?
    ENV.fetch("ADMIN_PASSWORD") # REQUIRED in production
  else
    # Local default if you don't set ADMIN_PASSWORD
    ENV.fetch("ADMIN_PASSWORD", "ClearPlanner!2026-DevTeam#1")
  end

admin = User.find_or_initialize_by(email: ADMIN_EMAIL)
admin.password = admin_password
admin.password_confirmation = admin_password
admin.username = "admin"
admin.confirmed_at = Time.current

# Works if you added enum role: { user: 0, admin: 1 }
# If you haven't migrated role yet, this will raise (which is good — forces consistency).
admin.role = :admin

admin.save!
puts "Ensured admin account: #{admin.email}"

# ------------------------------------
# Demo seed (LOCAL only unless opt-in)
# ------------------------------------
seed_demo_data = if Rails.env.production?
  ENV["SEED_DEMO_DATA"] == "true"
else
  # seed demo users in development by default, can disable with SEED_DEMO_DATA=false
  ENV.fetch("SEED_DEMO_DATA", "true") == "true"
end

unless seed_demo_data
  puts "Skipping demo seed data."
  puts "DONE"
  exit
end

DEMO_EMAILS = %w[chase@example.com landon@example.com anousith@example.com].freeze

# Clean slate for demo users (idempotent)
demo_user_ids = User.where(email: DEMO_EMAILS).pluck(:id)
demo_course_ids = Course.where(user_id: demo_user_ids).pluck(:id)
# Tasks reference course_items (FK), so clear them before course_items.
Task.where(user_id: demo_user_ids).delete_all
Block.where(user_id: demo_user_ids).delete_all
CalendarDraft.where(user_id: demo_user_ids).delete_all
CourseItem.where(course_id: demo_course_ids).delete_all
Course.where(user_id: demo_user_ids).delete_all
WorkShift.where(user_id: demo_user_ids).delete_all
Event.where(user_id: demo_user_ids).delete_all
Notification.where(user_id: demo_user_ids).delete_all
User.where(id: demo_user_ids).delete_all

now = Time.zone.now
week_start = now.beginning_of_week(:monday)
demo_password = ENV.fetch("DEMO_PASSWORD", SecureRandom.hex(16))

users_data = [
  {
    email: "chase@example.com",
    password: demo_password,
    username: "chase",
    role: :user,
    confirmed_at: Time.current,
    events: [
      {
        color: "#F97316",
        title: "Capstone Sprint planning",
        starts_at: week_start.change(hour: 12, min: 0) + 1.day,
        ends_at: week_start.change(hour: 13, min: 30) + 1.day,
        location: "Discord",
        description: "Plan Sprint 2"
      },
      {
        color: "#22C55E",
        recurring: true,
        repeat_days: [ 1, 3, 5 ],
        repeat_until: now + 14.days,
        title: "Gym",
        starts_at: now.change(hour: 16, min: 0) - 5.days,
        ends_at: now.change(hour: 17, min: 0) - 5.days,
        location: "Gym"
      },
      {
        color: "#3B82F6",
        title: "Super Battle Golf",
        starts_at: week_start.change(hour: 10, min: 0) + 3.days,
        ends_at: week_start.change(hour: 10, min: 45) + 3.days
      }
    ],
    courses: [
      {
        color: "#06B6D4",
        title: "Creative Writing",
        location: "MTG 410",
        start_time: "9:00",
        end_time: "10:15",
        start_date: now.to_date - 3.months,
        end_date: now.to_date + 3.months,
        repeat_days: [ 1, 3, 5 ],
        course_items: [
          {
            title: "Chapter 1 Reading",
            due_at: week_start.change(hour: 7, min: 0) + 1.day,
            kind: 4
          },
          {
            title: "Outline for Essay 1",
            due_at: week_start.change(hour: 7, min: 0) + 3.days,
            kind: 3
          }
        ]
      }
    ],
    work_shifts: [
      {
        color: "#FFFFFF",
        title: "Programming Job Night Shift",
        recurring: true,
        repeat_days: [ 1, 2, 3, 4, 5, 6 ],
        start_time: "17:00",
        end_time: "22:00",
        start_date: now.to_date - 1.weeks,
        repeat_until: now.to_date + 1.weeks
      }
    ]
  },
  {
    email: "landon@example.com",
    password: demo_password,
    username: "landon",
    role: :user,
    confirmed_at: Time.current,
    events: [
      {
        color: "#FFFFFF",
        title: "Sprint planning for Capstone",
        starts_at: week_start.change(hour: 11, min: 0) + 1.day,
        ends_at: week_start.change(hour: 12, min: 0) + 1.day,
        location: "Discord",
        description: "Planning second sprint for capstone class."
      },
      {
        color: "#FF0000",
        recurring: true,
        repeat_until: now + 14.days,
        repeat_days: [ 2, 4 ],
        title: "Studying(Math)",
        starts_at: week_start.change(hour: 16, min: 0) + 1.day,
        ends_at: week_start.change(hour: 17, min: 0) + 1.day,
        location: "Home"
      },
      {
        color: "#14B8A6",
        recurring: true,
        repeat_until: now + 14.days,
        repeat_days: [ 0 ],
        title: "Fishing",
        starts_at: week_start.change(hour: 7, min: 0) + 6.days,
        ends_at: week_start.change(hour: 10, min: 0) + 6.days,
        location: "Home"
      }
    ],
    courses: [
      {
        color: "#8B5CF6",
        title: "Reverse Engineering",
        location: "IASB 216",
        start_time: "9:00",
        end_time: "10:15",
        start_date: now.to_date - 3.months,
        end_date: now.to_date + 3.months,
        repeat_days: [ 2, 4 ],
        course_items: [
          {
            title: "Lab 1",
            due_at: week_start.change(hour: 7, min: 0) + 1.day,
            kind: 3
          }
        ]
      },
      {
        color: "#F43F5E",
        title: "Chaos Theory",
        location: "NETH 105",
        start_time: "13:00",
        end_time: "15:50",
        start_date: now.to_date - 3.months,
        end_date: now.to_date + 3.months,
        repeat_days: [ 1, 3, 5 ],
        course_items: [
          {
            title: "IEEE Conference",
            due_at: week_start.change(hour: 7, min: 0) + 3.day,
            kind: 7
          }
        ]
      }
    ],
    work_shifts: [
      {
        color: "#3B82F6",
        title: "Target Morning Shift",
        recurring: true,
        repeat_days: [ 1, 3, 5 ],
        start_time: "4:00",
        end_time: "12:30",
        start_date: now.to_date - 1.weeks,
        repeat_until: now.to_date + 2.weeks
      },
      {
        color: "#000000",
        title: "NASA Night Shift",
        recurring: true,
        repeat_days: [ 2, 6 ],
        start_time: "18:00",
        end_time: "23:00",
        start_date: now.to_date - 1.weeks,
        repeat_until: now.to_date + 2.weeks
      }
    ]
  },
  {
    # Dedicated user for exercising the AI plan feature (plan_tasks). Follows the
    # same events/courses/course_items/work_shifts pattern as the others, and
    # additionally seeds ACTIVE availability blocks + UNSCHEDULED tasks — both
    # required for plan_tasks to actually place anything.
    email: "anousith@example.com",
    password: demo_password,
    username: "anousith",
    role: :user,
    confirmed_at: Time.current,
    events: [
      {
        color: "#F59E0B",
        title: "Group Project Standup",
        # 12:30–1:00 PM Wed: right after the Algorithms class (ends 12:15) and
        # before the Afternoon Study block (starts 1:00), so no overlap.
        starts_at: week_start.change(hour: 12, min: 30) + 2.days,
        ends_at: week_start.change(hour: 13, min: 0) + 2.days,
        location: "Discord",
        description: "Weekly sync with the project team"
      },
      {
        color: "#10B981",
        recurring: true,
        repeat_days: [ 2, 4 ],
        repeat_until: now + 14.days,
        title: "Yoga",
        starts_at: week_start.change(hour: 7, min: 0) + 1.day,
        ends_at: week_start.change(hour: 8, min: 0) + 1.day,
        location: "Rec Center"
      }
    ],
    courses: [
      {
        color: "#6366F1",
        title: "Algorithms",
        location: "ALGO 201",
        start_time: "11:00",
        end_time: "12:15",
        start_date: now.to_date - 3.months,
        end_date: now.to_date + 3.months,
        repeat_days: [ 1, 3, 5 ],
        course_items: [
          {
            title: "Problem Set 4",
            due_at: week_start.change(hour: 7, min: 0) + 3.days,
            kind: 0
          },
          {
            title: "Final Project Proposal",
            due_at: week_start.change(hour: 7, min: 0) + 5.days,
            kind: 3
          }
        ]
      },
      {
        color: "#EC4899",
        title: "Database Systems",
        location: "DB 300",
        start_time: "14:00",
        end_time: "15:15",
        start_date: now.to_date - 3.months,
        end_date: now.to_date + 3.months,
        repeat_days: [ 2, 4 ],
        course_items: [
          {
            title: "Query Optimization Lab",
            due_at: week_start.change(hour: 7, min: 0) + 4.days,
            kind: 5
          }
        ]
      }
    ],
    work_shifts: [
      {
        color: "#0EA5E9",
        title: "Library Desk Shift",
        recurring: true,
        repeat_days: [ 1, 3 ],
        start_time: "16:00",
        end_time: "20:00",
        start_date: now.to_date - 1.weeks,
        repeat_until: now.to_date + 2.weeks
      }
    ],
    # Active availability windows the planner schedules tasks into. Labels/colors
    # match the app's routine builder categories (Scheduling::BlockRoutine:
    # Study #6366f1, Deep Work #10b981, Errands #f59e0b) so they read like
    # routine-generated blocks.
    blocks: [
      {
        label: "Study",
        color: "#6366f1",
        repeat_days: [ 1, 2, 3, 4, 5 ],
        start_minute: 13 * 60, # 1:00 PM
        end_minute: 18 * 60,   # 6:00 PM
        status: "active"
      },
      {
        label: "Deep Work",
        color: "#10b981",
        repeat_days: [ 0, 6 ],
        start_minute: 10 * 60, # 10:00 AM
        end_minute: 16 * 60,   # 4:00 PM
        status: "active"
      }
    ],
    # Unscheduled + incomplete tasks (scheduled_at defaults to nil). Deadline-linked
    # tasks reference a course_item by title; the last two are backlog with no deadline.
    tasks: [
      { title: "Solve Problem Set 4",           duration_minutes: 90,  course_item_title: "Problem Set 4" },
      { title: "Draft project proposal",        duration_minutes: 120, course_item_title: "Final Project Proposal" },
      { title: "Complete Query Optimization Lab", duration_minutes: 75, course_item_title: "Query Optimization Lab" },
      { title: "Review algorithms lecture notes", duration_minutes: 60 },
      { title: "Make midterm flashcards",       duration_minutes: 45 }
    ]
  }
]

users_data.each do |u|
  events = u.delete(:events) || []
  courses = u.delete(:courses) || []
  work_shifts = u.delete(:work_shifts) || []
  blocks = u.delete(:blocks) || []
  tasks = u.delete(:tasks) || []

  user = User.create!(u)
  events.each { |e| user.events.create!(e) }

  course_items_by_title = {}
  courses.each do |course_attrs|
    course_items = course_attrs.delete(:course_items) || []
    course = user.courses.create!(course_attrs)
    course_items.each do |item_attrs|
      item = course.course_items.create!(item_attrs)
      course_items_by_title[item.title] = item
    end
  end

  work_shifts.each { |shift_attrs| user.work_shifts.create!(shift_attrs) }
  blocks.each { |block_attrs| user.blocks.create!(block_attrs) }

  tasks.each do |task_attrs|
    ci_title = task_attrs.delete(:course_item_title)
    course_item = ci_title ? course_items_by_title.fetch(ci_title) : nil
    user.tasks.create!(task_attrs.merge(course_item: course_item))
  end

  puts "Created demo user #{user.email} with #{events.size} events, #{courses.size} courses, " \
       "#{work_shifts.size} work shifts, #{blocks.size} blocks, #{tasks.size} tasks"
end

puts "DONE"
