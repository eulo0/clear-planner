# frozen_string_literal: true

class UniversityCalendarController < ApplicationController
  layout "app_shell"

  before_action :authenticate_user!

  IMPORT_COLOR = "#60A5FA"

  def preview
    @mode = :rss
    @rss_url = params[:rss_url].to_s.strip
    return unless @rss_url.present?

    @items = UniversityCalendar::RssFetcher.call(@rss_url)
    @existing_keys = existing_event_keys
  rescue => e
    flash.now[:alert] = "Could not load calendar feed: #{e.message}"
    @items = []
    @existing_keys = Set.new
  end

  def pdf_preview_page
    @mode = :pdf
    render :preview
  end

  def pdf_preview
    @mode = :pdf

    @pdf_errors = []

    unless params[:pdf_file].present?
      @pdf_errors << "Please select a PDF file."
      render :preview and return
    end

    file = params[:pdf_file]
    unless file.content_type == "application/pdf"
      @pdf_errors << "Only PDF files are supported."
      render :preview and return
    end

    if file.size > 800.kilobytes
      @pdf_errors << "File size is over 800 KB."
      render :preview and return
    end

    pdf_data = file.read
    @items = UniversityCalendar::PdfParser.call(pdf_data)
    @existing_keys = existing_event_keys
    render :preview
  rescue => e
    @pdf_errors = [ "Could not parse PDF: #{e.message}" ]
    @items = []
    @existing_keys = Set.new
    render :preview
  end

  def import
    items    = params[:items] || {}
    imported = 0
    removed  = 0

    items.each_value do |item|
      if item[:_remove] == "1"
        removed += 1
        next
      end

      current_user.events.create!(
        title:       item[:title],
        description: item[:description],
        location:    item[:location],
        starts_at:   item[:starts_at].present? ? Time.zone.parse(item[:starts_at]) : nil,
        ends_at:     item[:ends_at].present? ? Time.zone.parse(item[:ends_at]) : nil,
        all_day:     item[:all_day] == "true",
        color:       IMPORT_COLOR
      )
      imported += 1
    end

    redirect_to events_path, notice: "Imported #{imported} event(s). #{removed} event(s) removed."
  rescue => e
    redirect_to events_path, alert: "Import failed: #{e.message}"
  end

  private

  def existing_event_keys
    current_user.events.pluck(:title, :starts_at).map do |title, starts_at|
      event_key(title, starts_at)
    end.to_set
  end

  # Deduplicate by title + date (ignoring time-of-day differences for all-day events)
  def event_key(title, starts_at)
    "#{title.to_s.downcase.strip}|#{starts_at&.to_date}"
  end
end
