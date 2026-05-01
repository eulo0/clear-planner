class WorkShiftException < ApplicationRecord
  belongs_to :work_shift

  validates :excluded_date, presence: true, uniqueness: { scope: :work_shift_id }
end
