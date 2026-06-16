module Ai
  module Tools
    class EditEvent < Ai::Tools::Base
      desc "Edit an existing event on the user's calendar. Use this when the user asks to change, update, move, or reschedule an event. Only include fields that should be changed."

      param :event_id,         type: :string,  desc: "The ID of the event to edit (can be a draft temp id like d_abc12345)"
      param :title,            type: :string,  required: false, desc: "New title"
      param :description,      type: :string,  required: false, desc: "New description"
      param :starts_at,        type: :string,  required: false, desc: "New start date/time in ISO 8601 format"
      param :ends_at,          type: :string,  required: false, desc: "New end date/time in ISO 8601 format"
      param :duration_minutes, type: :integer, required: false, desc: "New duration in minutes"
      param :location,         type: :string,  required: false, desc: "New location"
      param :color,            type: :string,  required: false, desc: "New hex color like #34D399"

      def execute(event_id:, **rest)
        args = rest.transform_keys(&:to_s).merge("event_id" => event_id)
        Ai::ToolExecutor.new(Ai.current_context).execute("edit_event", args).to_json
      end
    end
  end
end
