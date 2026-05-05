class User < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :syllabuses, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :work_shifts, dependent: :destroy
  has_many :calendar_drafts, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :owned_projects, class_name: "Project", dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships
  has_many :sent_project_invitations, class_name: "ProjectInvitation", foreign_key: :sender_id, dependent: :destroy

  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  enum :role, { user: 0, admin: 1 }
  has_one_attached :avatar
  validates :username, length: { in: 2..32 }

  # ── Theme ────────────────────────────────────────────────
  THEMES = %w[green blue purple rose amber cyan pink red lime slate orange mono nebula aurora sunset latech].freeze
  THEME_DEFAULT = "green".freeze

  def theme
    return super if THEMES.include?(super)
    return super if custom_themes.key?(super)
    THEME_DEFAULT
  end

  def update_theme(params)
    theme_name = params[:theme].to_s
    if THEMES.include?(theme_name) || custom_themes.key?(theme_name)
      update(theme: theme_name)
    else
      update(theme: THEME_DEFAULT)
    end
  end

  def custom_theme?
    custom_themes.key?(theme)
  end

  def current_custom_theme_variables
    return {} unless custom_theme?
    custom_themes[theme] || {}
  end

  def save_custom_theme(name, variables)
    updated = (custom_themes || {}).merge(name => variables)
    update(custom_themes: updated)
  end

  def delete_custom_theme(name)
    updated = (custom_themes || {}).except(name)
    was_active = theme == name
    update(
      custom_themes: updated,
      theme: was_active ? THEME_DEFAULT : theme
    )
  end
  # ─────────────────────────────────────────────────────────

  def avatar_thumbnail
    avatar.variant(resize: "150x150!").processed
  end

  def self.from_omniauth(auth)
    email = auth&.info&.email.to_s.strip.downcase
    return nil if email.blank?
    return nil unless auth&.info&.email_verified.to_s == "true"

    user = find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_by(email: email)

    if user
      user.update(provider: auth.provider, uid: auth.uid)
    else
      username = email.split("@").first
      # This is so their username isn't an invalid length by the model
      username = "User" if username.length < 2 || username.length > 32

      user = new(
        email:    email,
        username: username,
        password: Devise.friendly_token[0, 20],
        provider: auth.provider,
        uid:      auth.uid
      )
      if user.respond_to?(:skip_confirmation!) && user.has_attribute?(:confirmed_at)
        user.skip_confirmation!
      end
      user.save
    end

    user
  end

  def password_required?
    super && provider.blank?
  end
end
