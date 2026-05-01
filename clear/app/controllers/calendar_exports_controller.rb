# frozen_string_literal: true

class CalendarExportsController < ApplicationController
  before_action :authenticate_user!

  def show
    ics_data = CalendarExportService.new(current_user).generate
    send_data ics_data,
              filename: "clear_calendar.ics",
              type: "text/calendar; charset=utf-8",
              disposition: "attachment"
  end
end
