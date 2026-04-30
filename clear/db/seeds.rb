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

DEMO_EMAILS = %w[chase@example.com landon@example.com].freeze

# Clean slate for demo users (idempotent)
demo_user_ids = User.where(email: DEMO_EMAILS).pluck(:id)
demo_course_ids = Course.where(user_id: demo_user_ids).pluck(:id)
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
  }
]

users_data.each do |u|
  events = u.delete(:events) || []
  courses = u.delete(:courses) || []
  work_shifts = u.delete(:work_shifts) || []

  user = User.create!(u)
  events.each { |e| user.events.create!(e) }

  courses.each do |course_attrs|
    course_items = course_attrs.delete(:course_items) || []
    course = user.courses.create!(course_attrs)
    course_items.each { |item_attrs| course.course_items.create!(item_attrs) }
  end

  work_shifts.each { |shift_attrs| user.work_shifts.create!(shift_attrs) }

  puts "Created demo user #{user.email} with #{events.size} events, #{courses.size} courses, #{work_shifts.size} work shifts"
end

puts "DONE"
