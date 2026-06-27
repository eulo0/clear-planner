# frozen_string_literal: true

# Canvas sync is managed inline from the profile drawer (profiles/_canvas_sync_section).
# These actions back that UI and redirect to the dashboard with a flash, mirroring
# the calendar-import flow.
class CanvasSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription

  def create
    @subscription = current_user.canvas_subscription || current_user.build_canvas_subscription
    @subscription.assign_attributes(subscription_params)

    if @subscription.save
      CanvasSyncRefreshJob.perform_later(@subscription.id)
      redirect_to dashboard_path, notice: "LMS feed connected. Syncing…"
    else
      redirect_to dashboard_path, alert: connect_error_message
    end
  end

  def update
    redirect_to dashboard_path, alert: "No LMS feed to update." and return if @subscription.nil?

    if @subscription.update(subscription_params)
      CanvasSyncRefreshJob.perform_later(@subscription.id)
      redirect_to dashboard_path, notice: "LMS feed updated. Syncing…"
    else
      redirect_to dashboard_path, alert: connect_error_message
    end
  end

  def destroy
    @subscription&.destroy
    redirect_to dashboard_path, notice: "LMS sync removed."
  end

  def refresh
    CanvasSyncRefreshJob.perform_later(@subscription.id) if @subscription
    redirect_to dashboard_path, notice: "Syncing…"
  end

  private

  def set_subscription
    @subscription = current_user.canvas_subscription
  end

  def subscription_params
    params.require(:canvas_subscription).permit(:feed_url)
  end

  def connect_error_message
    @subscription.errors.full_messages.to_sentence.presence || "Could not connect LMS feed."
  end
end
