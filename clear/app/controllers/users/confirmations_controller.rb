class Users::ConfirmationsController < Devise::ConfirmationsController
  def new
    redirect_to new_user_session_path, alert: "Please sign in and request a new confirmation email there."
  end

  def create
    email = params.dig(:user, :email).to_s.strip
    email = params[:email].to_s.strip if email.blank?
    return redirect_to(new_user_session_path, alert: "Enter your email, then resend confirmation.") if email.blank?

    key_email = email.downcase.presence || "unknown"
    cache_key = "confirmations:resend:#{request.remote_ip}:#{key_email}"

    if Rails.cache.exist?(cache_key)
      return redirect_to(
        new_user_session_path(user: { email: email }),
        alert: "Please wait before requesting another confirmation email."
      )
    end

    self.resource = resource_class.send_confirmation_instructions(resource_params)

    if successfully_sent?(resource)
      Rails.cache.write(cache_key, true, expires_in: 10.seconds)
      redirect_to new_user_session_path(user: { email: email }),
                  flash: { confirmation_sent: "Confirmation email sent. Check your inbox or spam." }
      return
    end

    if resource.errors.added?(:email, :already_confirmed)
      redirect_to new_user_session_path(user: { email: email }),
                  alert: "This account is already confirmed. Please sign in."
    else
      redirect_to new_user_session_path,
                  alert: "Could not send confirmation email. Verify the address and try again."
    end
  end

  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      return redirect_to(new_user_session_path)
    end
    if resource.errors.added?(:email, :already_confirmed)
      redirect_to new_user_session_path, alert: "Your account is already confirmed. Please sign in."
    else
      redirect_to new_user_session_path, alert: "That confirmation link is invalid or expired. Please request a new confirmation email."
    end
  end
end
