class Project < ApplicationRecord
  before_create :generate_invite_token
  has_many :events, dependent: :destroy
  has_many :courses, dependent: :destroy

  has_many :project_memberships, dependent: :destroy
  has_many :project_messages, dependent: :destroy
  has_many :users, through: :project_memberships, source: :user
  has_many :project_invitations, dependent: :destroy
  belongs_to :owner, class_name: "User", foreign_key: :user_id, optional: true

  validates :title, presence: true


  def membership_for(user)
    project_memberships.find_by(user: user)
  end

  def notify_member_joined(new_user)
    display_name = new_user.username.presence || new_user.email

    Notification.create!(
      user: new_user,
      notifiable: self,
      category: "group_member_joined",
      message: %(You joined "#{title}")
    )

    users.where.not(id: new_user.id).find_each do |member|
      Notification.create!(
        user: member,
        notifiable: self,
        category: "group_member_joined",
        message: %(#{display_name} joined "#{title}")
      )
    end
  end

  def role_for(user)
    membership_for(user)&.role
  end

  def generate_invite_token
    self.invite_token = SecureRandom.hex(10)
  end

  def occurrences_for_week(start_date)
    week_start  = start_date.beginning_of_week
    range_start = week_start.beginning_of_day
    range_end   = (week_start + 6.days).end_of_day

    events
      .where("starts_at <= ?", range_end)
      .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
      .order(starts_at: :asc)
      .flat_map { |e| e.occurrences_between(range_start, range_end) }
      .sort_by(&:starts_at)
  end

  def occurrences_for_month(date)
    range_start = date.beginning_of_month.beginning_of_day
    range_end   = date.end_of_month.end_of_day

    events
      .where("starts_at <= ?", range_end)
      .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
      .order(starts_at: :asc)
      .flat_map { |e| e.occurrences_between(range_start, range_end) }
      .sort_by(&:starts_at)
  end

  def occurrences_for_day(date)
    range_start = date.beginning_of_day
    range_end   = date.end_of_day

    events
      .where("starts_at <= ?", range_end)
      .where("recurring = FALSE OR repeat_until >= ?", range_start.to_date)
      .order(starts_at: :asc)
      .flat_map { |e| e.occurrences_between(range_start, range_end) }
      .sort_by(&:starts_at)
  end
end
