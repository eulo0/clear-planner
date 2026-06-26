# frozen_string_literal: true

require "date"
require "json"
require "tempfile"

module Syllabuses
  # AI-backed syllabus extraction. Sends PDFs straight to a vision-capable
  # Claude model (handles text *and* table-heavy layouts the regex drops) and
  # DOCX as extracted text, returning the same `{ attrs:, items: }` shape the
  # regex extractors produce so `SyllabusParseJob#build_course_draft` is reused
  # unchanged.
  #
  # Raises AiExtractor::Error on any failure so the job can fall back to regex.
  class AiExtractor
    Error = Class.new(StandardError)

    MODEL      = ENV.fetch("LLM_MODEL", "claude-haiku-4-5-20251001")
    MAX_TOKENS = 4_000

    PROMPT = <<~PROMPT
      You are extracting structured data from a university course syllabus.
      Read the ENTIRE document, including the course schedule and any tables.

      Pairing deliverables with dates — read carefully:
      - A deliverable's due date is often NOT labeled "due" and may NOT be on the
        same line as the deliverable. In a course schedule, each row/week has a
        date (or parenthesized date like "(4/15/2026)"), and any homework, exam,
        quiz, lab, project, or presentation listed on or immediately next to that
        row is due on that date. Associate each deliverable with the schedule
        date on its row even when no "due" label is present.
      - When a date range or list like "(3/09,11,16/2025)" appears, treat the
        relevant single date as the due date (usually the last one).
      - Extract EVERY homework (HW01, HW02, ...), exam, quiz, lab, project, and
        seminar/presentation, and give each its schedule date when one exists.

      Course start/end dates:
      - start_date and end_date are the first and last days the class meets. If the
        syllabus does not state them explicitly, DERIVE them from the schedule:
        start_date = the earliest date that appears in the course schedule,
        end_date = the latest date that appears in the course schedule.

      Rules:
      - Use ONLY dates that actually appear in the document. Never invent a date,
        but DO associate a deliverable with a nearby schedule date that is present.
      - Copy the year exactly as written in the document, even if it looks wrong.
      - If a deliverable genuinely has no date anywhere near it, use an empty string.
      - For any course field not present in the syllabus, return an empty string "".
    PROMPT

    def self.call(syllabus)
      new(syllabus).call
    end

    def initialize(syllabus)
      @syllabus = syllabus
    end

    def call
      data = coerce_hash(request_extraction)
      raise Error, "empty AI response" if data.blank?

      attrs = build_attrs(data)
      items = build_items(data, term_year: term_year_from(attrs[:term]))

      raise Error, "no usable content extracted" if attrs.compact.blank? && items.empty?

      { attrs: attrs, items: items }
    rescue Error
      raise
    rescue StandardError => e
      # Any other failure on the AI path (RubyLLM/HTTP/timeout, JSON parse,
      # ActiveStorage download, Tempfile I/O, TextExtractor's `.doc` raise, …)
      # must surface as AiExtractor::Error so the job falls back to regex rather
      # than crashing the whole import.
      raise Error, "#{e.class}: #{e.message}"
    end

    private

    def request_extraction
      @syllabus.is_pdf? ? request_with_pdf : request_with_text
    end

    def request_with_pdf
      with_pdf_tempfile do |path|
        chat.ask(PROMPT, with: path).content
      end
    end

    def request_with_text
      text = Syllabuses::TextExtractor.call(@syllabus)
      raise Error, "no extractable text" if text.blank?

      chat.ask("#{PROMPT}\n\n---- SYLLABUS TEXT ----\n#{text}").content
    end

    def chat
      RubyLLM.chat(model: MODEL)
             .with_schema(Syllabuses::ExtractionSchema)
             .with_params(temperature: 0, max_tokens: MAX_TOKENS)
    end

    def with_pdf_tempfile
      Tempfile.create([ "syllabus", ".pdf" ]) do |tmp|
        tmp.binmode
        tmp.write(@syllabus.file.download)
        tmp.flush
        yield tmp.path
      end
    end

    # RubyLLM's `with_schema` returns parsed JSON, but tolerate a raw string too.
    def coerce_hash(content)
      case content
      when Hash   then content.deep_stringify_keys
      when String then JSON.parse(content)
      else {}
      end
    rescue JSON::ParserError
      {}
    end

    def build_attrs(data)
      professor = presence(data["professor"])

      {
        title:        presence(data["title"]),
        code:         presence(data["code"]),
        term:         presence(data["term"]),
        professor:    professor,
        instructor:   professor,
        meeting_days: presence(data["meeting_days"]),
        location:     presence(data["location"]),
        office:       presence(data["office"]),
        office_hours: presence(data["office_hours"]),
        start_date:   presence(data["start_date"]),
        end_date:     presence(data["end_date"]),
        description:  presence(data["description"]),
        start_time:   presence(data["start_time"]),
        end_time:     presence(data["end_time"])
      }
    end

    def build_items(data, term_year:)
      items = data["course_items"]
      return [] unless items.is_a?(Array)

      items.filter_map do |raw|
        next unless raw.is_a?(Hash)

        title = presence(raw["title"])
        next if title.blank?

        {
          title:   title,
          kind:    normalize_kind(raw["kind"]),
          due_at:  validated_due_at(raw["due_at"], term_year),
          details: presence(raw["details"])
        }.compact
      end
    end

    # Hallucination guard: keep a due date only if it parses and falls within a
    # plausible window of the term year. A bad date is dropped (item kept,
    # dateless) rather than trusted.
    def validated_due_at(raw, term_year)
      return nil if raw.blank?

      date = Date.iso8601(raw.to_s) rescue (Date.parse(raw.to_s) rescue nil)
      return nil unless date
      return nil if term_year && (date.year - term_year).abs > 1

      date.to_s
    end

    def normalize_kind(raw)
      kind = raw.to_s.strip.downcase
      Syllabuses::ExtractionSchema::ITEM_KINDS.include?(kind) ? kind : "assignment"
    end

    def term_year_from(term)
      term.to_s[/\b(20\d{2})\b/, 1]&.to_i
    end

    def presence(value)
      value.to_s.strip.presence
    end
  end
end
