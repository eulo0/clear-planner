# frozen_string_literal: true

# This is used for testing UI pieces
class UiController < ApplicationController
  layout "app_shell"

  before_action :require_admin

  def show
    start_date = Date.current
    @schedule_occurrences = calendar_occurrences_for_range(
      start_date.beginning_of_day,
      (start_date + 28.days).end_of_day,
      draft: current_user_draft
    )
    @schedule_start_date = start_date
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end
end
