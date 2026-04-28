module ApplicationHelper
  # Generates [[label, minutes], ...] for a duration dropdown in 15-min increments.
  # Tops out at 8 hours (480 minutes).
  DURATION_OPTIONS = (1..32).map do |i|
    minutes = i * 15
    hours, mins = minutes.divmod(60)
    label =
      if hours.zero?
        "#{mins} min"
      elsif mins.zero?
        "#{hours} hr"
      else
        "#{hours} hr #{mins} min"
      end
    [ label, minutes ]
  end.freeze

  def compare_options_for_select(drafts)
    [["Current Calendar", "current"]] + drafts.map { |d| [d.name, d.id.to_s] }
  end

  def rgba(hex, alpha)
    h = hex.to_s.delete("#")
    return "rgba(52,211,153,#{alpha})" unless h.match?(/\A\h{6}\z/)

    r, g, b = h.scan(/../).map(&:hex)
    "rgba(#{r},#{g},#{b},#{alpha})"
  end
end
