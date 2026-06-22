# frozen_string_literal: true

module Syllabuses
  # Maps a parsed syllabus `course_draft` hash to Course preview/form attributes
  # and back from submitted form params to Course attributes. Extracted from
  # SyllabusesController so the single-file flow and the onboarding batch flow
  # share one source of truth.
  module CourseDraftMapper
    module_function

    PREVIEW_FIELDS = %i[
      title code term professor meeting_days location office office_hours
      start_time end_time start_date end_date
    ].freeze

    # Fields the preview/review UI surfaces (and highlights when blank).
    def preview_fields
      PREVIEW_FIELDS
    end

    # Normalize a stored draft into values suitable for HTML form inputs
    # (HH:MM time fields, etc.).
    def normalized_draft_for_form(draft)
      d = (draft || {}).deep_dup
      d["start_time"] = normalize_time_for_input(d["start_time"])
      d["end_time"]   = normalize_time_for_input(d["end_time"])
      d["starts_at"]  = normalize_time_for_input(d["starts_at"])
      d["ends_at"]    = normalize_time_for_input(d["ends_at"])
      d
    end

    # Map a draft hash onto attributes for building a Course preview record,
    # tolerating either column-name variant the parser may produce.
    def remap_preview_attrs(draft)
      cols = Course.column_names
      out = (draft || {}).deep_dup
      out.delete("course_items")
      out.delete(:course_items)

      if cols.include?("start_time") && out["start_time"].blank? && out["starts_at"].present?
        out["start_time"] = out["starts_at"]
      end
      if cols.include?("end_time") && out["end_time"].blank? && out["ends_at"].present?
        out["end_time"] = out["ends_at"]
      end

      if cols.include?("instructor") && out["instructor"].blank? && out["professor"].present?
        out["instructor"] = out["professor"]
      end
      if cols.include?("professor") && out["professor"].blank? && out["instructor"].present?
        out["professor"] = out["instructor"]
      end

      out
    end

    # Map submitted form params back onto Course attributes.
    def remap_form_attrs(attrs)
      cols = Course.column_names
      out = (attrs || {}).deep_dup

      if cols.include?("start_time") && out["start_time"].blank? && out["starts_at"].present?
        out["start_time"] = out.delete("starts_at")
      end
      if cols.include?("end_time") && out["end_time"].blank? && out["ends_at"].present?
        out["end_time"] = out.delete("ends_at")
      end

      out
    end

    # Which preview fields are still blank on a built Course (drives the
    # amber "missing field" highlight in the preview/review UI).
    def missing_preview_fields(course)
      PREVIEW_FIELDS.select { |attr| course.public_send(attr).blank? }
    end

    def parse_draft_due_at(raw)
      return nil if raw.blank?
      Time.zone.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def normalize_time_for_input(v)
      return nil if v.blank?
      v.to_s.split(":").first(2).join(":")
    end
  end
end
