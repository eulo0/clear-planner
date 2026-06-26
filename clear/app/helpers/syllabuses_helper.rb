module SyllabusesHelper
  # Format a stored due_at value for an <input type="datetime-local">, which
  # only accepts "YYYY-MM-DDTHH:MM". Parsed items are frequently date-only
  # ("2025-03-16"), which the input treats as invalid and renders blank — so
  # pad those to midnight. Returns "" when the value is missing/unparseable.
  def datetime_local_value(raw)
    str = raw.to_s.strip
    return "" if str.blank?
    return "#{str}T00:00" if str.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Time.zone.parse(str)&.strftime("%Y-%m-%dT%H:%M").to_s
  rescue ArgumentError
    ""
  end
end
