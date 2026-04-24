# app/models/syllabus.rb
class Syllabus < ApplicationRecord
  belongs_to :user
  belongs_to :course, optional: true

  has_one_attached :file

  validates :title, presence: true
  validate :correct_file_type

  scope :with_files, -> { joins(:file_attachment) }

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/msword
  ].freeze

  enum :parse_status, {
    queued: "queued",
    processing: "processing",
    done: "done",
    failed: "failed"
  }, prefix: true

  def file_extension
    return nil unless file.attached?
    File.extname(file.filename.to_s).downcase
  end

  def is_pdf?
    file.attached? && file.content_type == "application/pdf"
  end

  def is_docx?
    file.attached? && file.content_type.in?([
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/msword"
    ])
  end

  private

  def correct_file_type
    if file.attached?
      if !file.content_type.in?(ALLOWED_CONTENT_TYPES)
        errors.add(:file, "must be a PDF or DOCX file")
      end
      if file.byte_size > 800_000
        errors.add(:file, "size is over 800 KB")
      end
    end
  end
end
