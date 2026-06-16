module Ai
  module Tools
    class ShowCreateForm < Ai::Tools::Base
      desc "Display a pre-filled event creation form inline in the chat. Use this instead of create_event when you are missing required information (title or start time). Pass any details you do have so the form is pre-populated for the user to complete."

      param :title,            type: :string,  required: false, desc: "Event title if known"
      param :description,      type: :string,  required: false, desc: "Optional description"
      param :starts_at,        type: :string,  required: false, desc: "Start date/time in ISO 8601 format if known"
      param :ends_at,          type: :string,  required: false, desc: "End date/time in ISO 8601 format if known"
      param :duration_minutes, type: :integer, required: false, desc: "Duration in minutes if known"
      param :location,         type: :string,  required: false, desc: "Location if known"
      param :color,            type: :string,  required: false, desc: "Hex color like #34D399 if known"

      def execute(**rest)
        args = rest.transform_keys(&:to_s)
        Ai::ToolExecutor.new(Ai.current_context).execute("show_create_form", args).to_json
      end
    end
  end
end
