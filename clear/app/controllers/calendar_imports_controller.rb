# frozen_string_literal: true

class CalendarImportsController < ApplicationController
  before_action :authenticate_user!

  # Tints imported events so users can spot what came in from a file.
  IMPORT_COLOR = "#A78BFA"
  MAX_FILE_SIZE = 1.megabyte

  def create
    file = params[:ics_file]

    # Validate the upload before doing any parsing.
    if file.blank?
      redirect_to profile_path, alert: "Please select a .ics file." and return
    end

    # Some browsers send a blank/odd MIME for .ics, so check extension too.
    unless file.original_filename.to_s.downcase.end_with?(".ics") || file.content_type.to_s.include?("calendar")
      redirect_to profile_path, alert: "Only .ics files are supported." and return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to profile_path, alert: "File is too large (max #{MAX_FILE_SIZE / 1024} KB)." and return
    end

    # Parse the file into event attribute hashes.
    items = CalendarImports::IcsParser.call(file.read)

    if items.empty?
      redirect_to profile_path, alert: "No events found in this file." and return
    end

    # Drop events that already ended so we don't fill the calendar with old stuff.
    upcoming = items.reject { |attrs| past_event?(attrs) }
    skipped  = items.size - upcoming.size

    if upcoming.empty?
      redirect_to profile_path, alert: "All #{items.size} event(s) in this file are in the past." and return
    end

    # Wrap inserts so a single bad row rolls back the whole import.
    imported = 0
    Event.transaction do
      upcoming.each do |attrs|
        current_user.events.create!(attrs.merge(color: IMPORT_COLOR))
        imported += 1
      end
    end

    notice = "Imported #{imported} event(s)."
    notice += " Skipped #{skipped} past event(s)." if skipped.positive?
    redirect_to dashboard_path, notice: notice
  rescue => e
    redirect_to profile_path, alert: "Could not import calendar: #{e.message}"
  end

  private

  # Recurring events are "past" only once their repeat_until is gone.
  # One-time events compare against ends_at when present, otherwise starts_at.
  def past_event?(attrs)
    if attrs[:recurring]
      attrs[:repeat_until].present? && attrs[:repeat_until] < Date.current
    else
      reference = attrs[:ends_at] || attrs[:starts_at]
      reference < Time.current
    end
  end
end
