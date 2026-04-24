# app/controllers/themes_controller.rb
class ThemesController < ApplicationController
  before_action :authenticate_user!

  def new
    render partial: "profiles/custom_theme_form"
  end

  def update
    if current_user.update_theme(theme_params)
      redirect_back fallback_location: authenticated_root_path, notice: "Theme saved!"
    else
      redirect_back fallback_location: authenticated_root_path, alert: "Couldn't save theme."
    end
  end

  def create
    name = custom_theme_params[:name].strip
    variables = custom_theme_params[:variables].to_h

    if name.blank?
      redirect_back fallback_location: profile_path, alert: "Theme name can't be blank."
      return
    end

    if current_user.save_custom_theme(name, variables)
      current_user.update(theme: name)
      redirect_to profile_path, notice: "Custom theme saved!"
    else
      redirect_back fallback_location: profile_path, alert: "Couldn't save theme."
    end
  end

  def destroy
    name = params[:id]
    current_user.delete_custom_theme(name)
    redirect_to authenticated_root_path, notice: "Theme deleted."
  end

  def reset
    current_user.update(theme: User::THEME_DEFAULT)
    redirect_back fallback_location: authenticated_root_path, notice: "Theme reset."
  end

  private

  def theme_params
    params.require(:theme).permit(:theme)
  end

  def custom_theme_params
    params.require(:custom_theme).permit(:name, variables: {})
  end
end
