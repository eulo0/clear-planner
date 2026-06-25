# frozen_string_literal: true

class SyllabusParseJob < ApplicationJob
  queue_as :default

  DEGRADED_WARNING = "Parsed with the basic (non-AI) reader — double-check dates and times."

  def perform(syllabus_id)
    syllabus = Syllabus.find(syllabus_id)

    syllabus.update!(parse_status: "processing", parse_error: nil)

    text = extract_text_safely(syllabus)
    attrs, items, source = extract(syllabus, text)

    draft = build_course_draft(attrs)
    draft[:course_items]  = items if items.present?
    draft[:source]        = source
    draft[:parse_warning] = DEGRADED_WARNING if source == "regex_fallback"

    syllabus.update!(
      parsed_text: text,
      parsed_at: Time.current,
      course_draft: draft,
      parse_status: "done",
      parse_error: nil
    )
  rescue => e
    syllabus&.update(parse_status: "failed", parse_error: "#{e.class}: #{e.message}")
    raise
  end

  private

  # Try the AI extractor first; on any AI failure, fall back to the regex
  # pipeline. The chosen path is tagged on the draft (`source`) and a warning is
  # surfaced when degraded, so a silent quality drop can't masquerade as a clean
  # parse.
  def extract(syllabus, text)
    result = ::Syllabuses::AiExtractor.call(syllabus)
    [ result[:attrs], result[:items], "ai" ]
  rescue ::Syllabuses::AiExtractor::Error => e
    Rails.logger.warn("[SyllabusParseJob] AI extraction failed (#{e.message}); falling back to regex")
    attrs = ::Syllabuses::CourseAttributesExtractor.call(text, fallback_title: syllabus.title)
    items = ::Syllabuses::CourseItemsExtractor.call(text, term: attrs[:term])
    [ attrs, items, "regex_fallback" ]
  end

  # Best-effort text for storage + the regex fallback. Never fails the parse
  # (a scanned PDF legitimately yields no text; the AI vision path covers it).
  def extract_text_safely(syllabus)
    ::Syllabuses::TextExtractor.call(syllabus)
  rescue => e
    Rails.logger.warn("[SyllabusParseJob] text extraction failed: #{e.message}")
    ""
  end

  def build_course_draft(attrs)
    draft = {}

    draft[:title]       = attrs[:title]
    draft[:code]        = attrs[:code]
    draft[:term]        = attrs[:term]
    draft[:professor]   = attrs[:professor]
    draft[:instructor]  = attrs[:instructor] || attrs[:professor]
    draft[:meeting_days]= normalize_meeting_days(attrs[:meeting_days])
    draft[:location]    = attrs[:location]
    draft[:office]      = attrs[:office]
    draft[:office_hours]= attrs[:office_hours]
    draft[:start_date]  = attrs[:start_date]
    draft[:end_date]    = attrs[:end_date]
    draft[:description] = attrs[:description]

    start_raw = attrs[:start_time] || attrs[:starts_at]
    end_raw   = attrs[:end_time]   || attrs[:ends_at]

    start_hhmm = normalize_time_for_db(start_raw)
    end_hhmm   = normalize_time_for_db(end_raw)

    if start_hhmm.present? && end_hhmm.present? && minutes(end_hhmm) <= minutes(start_hhmm)
      end_hhmm = nil
    end

    draft[:start_time] = start_hhmm
    draft[:end_time]   = end_hhmm

    draft[:starts_at]  = start_hhmm
    draft[:ends_at]    = end_hhmm

    draft.compact
  end

  def normalize_meeting_days(raw)
    s = raw.to_s.upcase.gsub(/[^MTWRF]/, "")
    s.presence
  end

  def normalize_time_for_db(v)
    return nil if v.blank?

    str =
      if v.is_a?(Time)
        v.strftime("%H:%M")
      else
        v.to_s.strip
      end

    if str.match?(/\A\d{1,2}:\d{2}:\d{2}\z/)
      str = str.split(":").first(2).join(":")
    end

    if str.match?(/\A\d{1,2}:\d{2}\z/)
      h, m = str.split(":")
      return format("%02d:%02d", h.to_i, m.to_i)
    end

    nil
  end

  def minutes(hhmm)
    h, m = hhmm.split(":").map(&:to_i)
    h * 60 + m
  end
end
