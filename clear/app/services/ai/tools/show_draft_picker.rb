module Ai
  module Tools
    class ShowDraftPicker < Ai::Tools::Base
      desc "Display a draft selection card inline in the chat so the user can pick or create a draft."

      def execute
        Ai::ToolExecutor.new(Ai.current_context).execute("show_draft_picker", {}).to_json
      end
    end
  end
end
