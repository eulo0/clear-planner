class ProjectsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  # Groups was retired from the nav: block the index + creation entry points, but
  # leave member-scoped actions (show/agenda/chat/join) intact so existing project
  # events and their project-scoped calendar keep working.
  before_action :redirect_removed_feature, only: %i[index new create destroy_all]
  before_action :set_project, only: %i[show edit update destroy agenda chat]
  before_action :require_owner!, only: %i[edit update]

  def index
    @q = params[:q].to_s.strip
    @projects = current_user.projects.order(:title)
    @projects = @projects.where("title ILIKE ?", "%#{@q}%") if @q.present?
  end

  def show
    session.delete(:calendar_draft_mode)
    session.delete(:active_calendar_draft_id)
    @current_user_draft = nil
    @current_user_drafts = nil

    @start_date =
      begin
        params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    @occurrences = @project.occurrences_for_week(@start_date)

    @blocked_intervals = group_blocked_intervals(@project, @start_date)

    month_occurrences = @project.occurrences_for_month(@start_date)
    @month_events_by_date = Hash.new { |h, k| h[k] = [] }
    month_occurrences.each { |occ| @month_events_by_date[occ.starts_at.in_time_zone.to_date] << occ }
    @month_date = @start_date
  end

  def new
    @project = Project.new
  end

  def edit
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      @project.project_memberships.create!(user: current_user, role: :owner)
      respond_to do |format|
        format.html { redirect_to project_path(@project), notice: "Group created." }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: "Group was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy_all
      current_user.projects.destroy_all
      redirect_to projects_path, notice: "All groups deleted."
  end

  def destroy
    if current_membership.owner?
      @project.destroy
      respond_to do |format|
        format.html { redirect_to projects_path, notice: "Group deleted.", status: :see_other }
      end
    else
      current_membership&.destroy
      respond_to do |format|
        format.html { redirect_to projects_path, notice: "You have left the group.", status: :see_other }
      end
    end
  end

  def join
    project = Project.find_by(invite_token: params[:token])

    if project.nil?
      redirect_to root_path, alert: "Invalid invite link"
      return
    end

    unless project.users.include?(current_user)
      project.project_memberships.create!(user: current_user, role: :viewer)
      project.notify_member_joined(current_user)
    end

    redirect_to project_path(project), notice: "You joined the group!"
  end

  def agenda
    @date =
      begin
        params[:date].present? ? Date.parse(params[:date]) : Date.current
      rescue ArgumentError
        Date.current
      end

    @occurrences = @project.occurrences_for_day(@date)

    now = Time.current
    @next_occurrence = @project.occurrences_for_week(now.to_date)
                                .find { |o| o.starts_at > now }
  end

  def chat
    @messages = @project.project_messages.includes(:user).order(created_at: :asc)
  end

  private

  def current_membership
    @current_membership ||= @project.membership_for(current_user)
  end

  def require_owner!
    unless current_membership&.owner?
      redirect_to project_path(@project), alert: "You don't have permission to do that."
    end
  end

  def occurrences_for_range(range_start, range_end)
    base_events = current_user.events

    non_recurring_events = base_events.where(recurring: false)
                                      .where(starts_at: range_start..range_end)

    recurring_events = base_events.where(recurring: true)
                                  .where("starts_at <= ?", range_end)
                                  .where("repeat_until >= ?", range_start.to_date)

    event_occurrences = (non_recurring_events + recurring_events).flat_map { |e| e.occurrences_between(range_start, range_end) }

    base_courses = current_user.courses
      .where("start_date <= ?", range_end.to_date)
      .where("end_date >= ?", range_start.to_date)
      .order(start_date: :asc)

    course_occurrences =
      base_courses.flat_map { |c| c.occurrences_between(range_start, range_end) }

    course_items =
      CourseItem
        .joins(:course)
        .where(courses: { user_id: current_user.id })
        .where(due_at: range_start..range_end)
        .includes(:course)

    (event_occurrences + course_occurrences + course_items.to_a)
      .sort_by(&:starts_at)
  end

  def set_project
    @project = current_user.projects.find_by(id: params[:id])
    unless @project
      redirect_to projects_path, alert: "Group not found or you are not a member."
    end
  end

  def project_params
    params.require(:project).permit(:title, :description)
  end
end
