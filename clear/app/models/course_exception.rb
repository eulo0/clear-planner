class CourseException < ApplicationRecord
  belongs_to :course

  validates :excluded_date, presence: true, uniqueness: { scope: :course_id }
end
