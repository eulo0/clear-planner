module Ai
  module Tools
    class SelectDraft < Ai::Tools::Base
      desc "Enter draft mode by selecting an existing calendar draft. Use this when the user asks to switch/change drafts or use a specific draft."

      param :name,     type: :string,  required: false, desc: "Draft name to select (case-insensitive)"
      param :draft_id, type: :integer, required: false, desc: "Optional draft ID to select"

      def execute(name: nil, draft_id: nil)
        args = {}
        args["name"]     = name     if name
        args["draft_id"] = draft_id if draft_id
        Ai::ToolExecutor.new(Ai.current_context).execute("select_draft", args).to_json
      end
    end
  end
end
