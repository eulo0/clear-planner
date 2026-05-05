class Users::AuthController < Devise::SessionsController
  def create
    email = params.dig(resource_name, :email).to_s.strip
    password = params.dig(resource_name, :password).to_s

    if email.present? && password.present?
      user = resource_class.find_by(email: email.downcase)

      if user && user.respond_to?(:confirmed?) && !user.confirmed? && user.valid_password?(password)
        user.send_confirmation_instructions
        session[:prefill_sign_in_email] = email
        return redirect_to(
          new_session_path(resource_name),
          alert: "You have to confirm your email address before continuing."
        )
      end
    end

    super
  end
end
