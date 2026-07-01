# frozen_string_literal: true

module Colorable
  extend ActiveSupport::Concern

  # WCAG-style luminance pick: dark text on light backgrounds, light on dark.
  def contrast_text_color
    hex = color.to_s.delete("#")
    return "#0A0A0A" unless hex.length == 6

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    luminance = (0.2126 * srgb_linear(r) + 0.7152 * srgb_linear(g) + 0.0722 * srgb_linear(b))
    luminance > 0.55 ? "#0A0A0A" : "#F9FAFB"
  end

  private

  def srgb_linear(channel)
    c = channel / 255.0
    c <= 0.03928 ? (c / 12.92) : (((c + 0.055) / 1.055)**2.4)
  end
end
