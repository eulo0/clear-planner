class ProjectInvitationsController < ApplicationController
  layout "app_shell"
  before_action :authenticate_user!
  before_action :set_project, only: %i[new create members]
  before_action :require_owner!, only: %i[new create]

  def new
    @invitation = @project.project_invitations.new
  end

  def create
    @invitation = @project.project_invitations.new(invitation_params)
    @invitation.sender = current_user

    if @invitation.save
      ProjectInvitationMailer.invite(@invitation).deliver_later
      redirect_to project_path(@project), notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def accept
    invitation = ProjectInvitation.find_by(token: params[:token])

    if invitation.nil?
      redirect_to root_path, alert: "Invalid invitation link."
      return
    end

    if invitation.accepted?
      redirect_to project_path(invitation.project), notice: "This invitation has already been accepted."
      return
    end

    invitation.accept!(current_user)
    redirect_to project_path(invitation.project), notice: "You joined \"#{invitation.project.title}\"!"
  end

  def members
    @members = @project.users
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

  def invitation_params
    params.require(:project_invitation).permit(:email)
  end
end
