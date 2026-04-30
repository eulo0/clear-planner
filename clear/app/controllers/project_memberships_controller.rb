class ProjectMembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :require_owner!

  def update
    membership = @project.project_memberships.find(params[:id])
    membership.update!(role: params[:role])
    head :ok
  end

  def destroy
    membership = @project.project_memberships.find(params[:id])
    membership.destroy!
    redirect_to members_project_project_invitations_path(@project), notice: "Member removed."
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:project_id])
    unless @project
      redirect_to projects_path, alert: "Project not found or you are not a member."
    end
  end

  def require_owner!
    unless @project.membership_for(current_user)&.owner?
      redirect_to project_path(@project), alert: "You don't have permission to do that."
    end
  end
end
