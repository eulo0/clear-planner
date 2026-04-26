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
         :recoverable, :rememberable, :validatable

  enum :role, { user: 0, admin: 1 }
  has_one_attached :avatar
  validates :username, length: { in: 2..32 }

  # ── Theme ────────────────────────────────────────────────
  THEMES = %w[green blue purple rose amber cyan pink red lime slate orange mono nebula aurora sunset latech].freeze
  THEME_DEFAULT = "green".freeze

  def theme
    THEMES.include?(super) ? super : THEME_DEFAULT
  end

  def update_theme(params)
    theme_name = params[:theme].to_s
    update(theme: THEMES.include?(theme_name) ? theme_name : THEME_DEFAULT)
  end
  # ─────────────────────────────────────────────────────────

  def avatar_thumbnail
    avatar.variant(resize: "150x150!").processed
  end
end
