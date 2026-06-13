module Ai
  module Tools
    class CreateEvent < Ai::Tools::Base
      desc "Create a new event on the user's calendar. Use this when the user asks to add, schedule, or create an event."

      param :title,            type: :string,  desc: "Title of the event"
      param :starts_at,        type: :string,  desc: "Start date/time in ISO 8601 format (e.g. 2026-03-20T14:00:00)"
      param :description,      type: :string,  required: false, desc: "Optional description or notes"
      param :ends_at,          type: :string,  required: false, desc: "Optional end date/time in ISO 8601 format"
      param :duration_minutes, type: :integer, required: false, desc: "Optional duration in minutes (used if ends_at is not provided)"
      param :location,         type: :string,  required: false, desc: "Optional location"
      param :color,            type: :string,  required: false, desc: "Optional hex color like #34D399"

      def execute(title:, starts_at:, **rest)
        args = rest.transform_keys(&:to_s).merge("title" => title, "starts_at" => starts_at)
        Ai::ToolExecutor.new(Ai.current_context).execute("create_event", args).to_json
      end
    end
  end
end
