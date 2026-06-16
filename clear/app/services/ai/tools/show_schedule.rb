module Ai
  module Tools
    class ShowSchedule < Ai::Tools::Base
      desc "Display the user's calendar schedule as an inline visual in the chat. Use this when the user asks to see, view, or show their schedule or calendar."

      param :start_date, type: :string, required: false, desc: "Start date in YYYY-MM-DD format (defaults to today)"

      def execute(start_date: nil)
        args = {}
        args["start_date"] = start_date if start_date
        Ai::ToolExecutor.new(Ai.current_context).execute("show_schedule", args).to_json
      end
    end
  end
end
