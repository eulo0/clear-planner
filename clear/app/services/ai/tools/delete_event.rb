module Ai
  module Tools
    class DeleteEvent < Ai::Tools::Base
      desc "Delete an event. Use this when the user asks to remove or delete an event."

      param :event_id, type: :string, desc: "The ID of the event to delete (can be a draft temp id like d_abc12345)"

      def execute(event_id:)
        Ai::ToolExecutor.new(Ai.current_context).execute("delete_event", { "event_id" => event_id }).to_json
      end
    end
  end
end
