# app/controllers/themes_controller.rb
class ThemesController < ApplicationController
  before_action :authenticate_user!

  def new
    render partial: "profiles/custom_theme_form"
  end

  def update
    if params[:custom_theme].present?
      original_name = params[:custom_theme][:original_name]
      new_name = params[:custom_theme][:name].strip
      variables = params[:custom_theme][:variables].to_unsafe_h

      updated = current_user.custom_themes.except(original_name).merge(new_name => variables)
      current_user.update(
        custom_themes: updated,
        theme: new_name
      )
      redirect_to profile_path, notice: "Theme updated!"
    else
      if current_user.update_theme(theme_params)
        redirect_back fallback_location: authenticated_root_path, notice: "Theme switched!"
      else
        redirect_back fallback_location: authenticated_root_path, alert: "Couldn't save theme."
      end
    end
  end

  def edit
    name = params[:id]
    variables = current_user.custom_themes[name] || {}
    render partial: "profiles/custom_theme_form", locals: { edit_name: name, edit_variables: variables }
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
    params.require(:custom_theme).permit(:name, :original_name, variables: {})
  end
end
