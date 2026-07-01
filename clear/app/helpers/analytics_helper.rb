# frozen_string_literal: true

module AnalyticsHelper
  # Per-type colors, matching Analytics Dashboard Prototype.html stat cards.
  # NOTE: intentionally differs from the old live page (Events were blue there).
  TYPE_COLORS = {
    event:    "#34d399",
    course:   "#60a5fa",
    task:     "#fbbf24",
    deadline: "#f87171"
  }.freeze

  STRESS_COLORS = { heavy: "#ef4444", moderate: "#f59e0b", calm: "#10b981" }.freeze

  # 390 => "6h 30m", 120 => "2h", 45 => "45m", 0 => "0m"
  def format_duration_short(minutes)
    minutes = minutes.to_i
    h = minutes / 60
    m = minutes % 60
    return "#{h}h#{m.positive? ? " #{m}m" : ""}" if h.positive?
    "#{m}m"
  end

  # 0 => "today", 1 => "tomorrow", 2..6 => "in N days", else short date
  def relative_day_label(date, today = Date.current)
    diff = (date.to_date - today).to_i
    case diff
    when 0 then "today"
    when 1 then "tomorrow"
    else diff.positive? ? "in #{diff} days" : date.to_date.strftime("%b %-d")
    end
  end

  def stress_level(score)
    score >= 75 ? :heavy : score >= 50 ? :moderate : :calm
  end

  def stress_color(score)
    STRESS_COLORS[stress_level(score)]
  end

  # Catmull-Rom -> cubic bezier smooth path. points: [[x,y], ...]
  def stress_smooth_path(points)
    return "" if points.size < 2
    t = 0.16
    d = +"M #{points[0][0]} #{points[0][1]}"
    (0...points.size - 1).each do |i|
      p0 = i.zero? ? points[i] : points[i - 1]
      p1 = points[i]
      p2 = points[i + 1]
      p3 = points[i + 2] || p2
      c1x = p1[0] + (p2[0] - p0[0]) * t
      c1y = p1[1] + (p2[1] - p0[1]) * t
      c2x = p2[0] - (p3[0] - p1[0]) * t
      c2y = p2[1] - (p3[1] - p1[1]) * t
      d << " C #{c1x.round(1)} #{c1y.round(1)} #{c2x.round(1)} #{c2y.round(1)} #{p2[0]} #{p2[1]}"
    end
    d
  end
end
