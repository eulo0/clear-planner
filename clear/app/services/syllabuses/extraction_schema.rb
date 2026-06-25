# frozen_string_literal: true

require "ruby_llm/schema"

module Syllabuses
  # Structured-output schema handed to Claude (via RubyLLM `with_schema`) when
  # parsing a syllabus. Fields mirror what `SyllabusParseJob#build_course_draft`
  # and `CourseItemsExtractor` consume, so AI output flows through the existing
  # normalization untouched.
  #
  # Every field is REQUIRED on purpose: Anthropic's structured-output grammar
  # rejects schemas with many optional fields as "Schema is too complex." The
  # model returns an empty string for values not present in the syllabus, and
  # AiExtractor#presence / #validated_due_at turn those back into nil.
  #
  # meeting_days uses the app's MTWRF convention (R = Thursday) — see
  # SyllabusParseJob#normalize_meeting_days.
  class ExtractionSchema < RubyLLM::Schema
    ITEM_KINDS = %w[assignment exam quiz lab project reading presentation seminar].freeze

    string :title, description: "Full course title, e.g. 'General Physics II' (empty string if absent)"
    string :code, description: "Course code, e.g. 'PHYS 262' (empty string if absent)"
    string :term, description: "Term and year, e.g. 'Fall 2024' (empty string if absent)"
    string :professor, description: "Instructor / professor name (empty string if absent)"

    string :meeting_days,
           description: "Weekly meeting days as letters using M,T,W,R,F (R = Thursday). " \
                        "E.g. Monday/Wednesday/Friday => 'MWF', Tuesday/Thursday => 'TR'. Empty string if absent."
    string :start_time, description: "Class start time, 24-hour 'HH:MM' (empty string if absent)"
    string :end_time, description: "Class end time, 24-hour 'HH:MM' (empty string if absent)"

    string :location, description: "Classroom / building / room (empty string if absent)"
    string :office, description: "Instructor office location (empty string if absent)"
    string :office_hours, description: "Office hours, free text (empty string if absent)"

    string :start_date,
           description: "First day the class meets, ISO 'YYYY-MM-DD'. If not stated explicitly, " \
                        "use the earliest date in the course schedule. Empty string only if no dates exist."
    string :end_date,
           description: "Last day the class meets, ISO 'YYYY-MM-DD'. If not stated explicitly, " \
                        "use the latest date in the course schedule. Empty string only if no dates exist."
    string :description, description: "Short course description (empty string if absent)"

    array :course_items,
          description: "Every graded or scheduled deliverable. Read tables carefully — due dates are " \
                       "often in a separate column from the item label. Use only dates that appear in " \
                       "the document; never invent a date. Empty array if there are none." do
      object do
        string :title, description: "Short deliverable label, e.g. 'Report 1 (R1)', 'Midterm Exam'"
        string :kind, enum: ITEM_KINDS, description: "Type of deliverable"
        string :due_at, description: "Due date as ISO 'YYYY-MM-DD', or empty string if none is stated"
        string :details, description: "Optional extra context (points, chapter, etc.); empty string if none"
      end
    end
  end
end
