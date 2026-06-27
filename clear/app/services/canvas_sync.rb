# frozen_string_literal: true

# Namespace + shared normalizers for Canvas ICS syncing.
module CanvasSync
  module_function

  # Course-code match key: case-insensitive, punctuation/space-insensitive.
  # "FORT 101" and "fort101" both normalize to "fort101".
  def normalize_code(value)
    value.to_s.downcase.gsub(/[^a-z0-9]/, "")
  end

  # Exact-title match key: case-insensitive, whitespace-collapsed.
  def normalize_title(value)
    value.to_s.downcase.strip.gsub(/\s+/, " ")
  end
end
