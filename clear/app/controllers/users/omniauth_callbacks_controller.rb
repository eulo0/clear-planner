class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = User.from_omniauth(request.env["omniauth.auth"])
    return redirect_to(new_user_session_path, alert: "Google account email is not verified.") if user.nil?

    if user.persisted?
      if user.confirmed?
        sign_in_and_redirect user, event: :authentication
        set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
        return
      end

      redirect_to new_user_session_path, notice: "A confirmation email has been sent to #{user.email}. Please confirm your account before signing in."
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url, alert: user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path, alert: "Google authentication failed."
  end
end
