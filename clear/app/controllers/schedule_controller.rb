# frozen_string_literal: true

class ScheduleController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  # Schedule was retired from the nav; block all direct access.
  before_action :redirect_removed_feature

  def week
    reference_date = params[:date]&.to_date || Date.current
    @week_start = reference_date.beginning_of_week(:monday)
    @days = (0..6).map { |i| @week_start + i.days }

    range_start = @week_start.beginning_of_day
    range_end   = (@week_start + 6.days).end_of_day

    items = calendar_occurrences_for_range(range_start, range_end)
    @items_by_day = items.group_by { |item| item.starts_at.to_date }
  end

  def show; end
end
