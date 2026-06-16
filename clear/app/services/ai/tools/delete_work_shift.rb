module Ai
  module Tools
    class DeleteWorkShift < Ai::Tools::Base
      desc "Delete a work shift. Use this when the user asks to remove or delete a work shift."

      param :shift_id, type: :string, desc: "The ID of the work shift to delete (can be a draft temp id like d_abc12345)"

      def execute(shift_id:)
        Ai::ToolExecutor.new(Ai.current_context).execute("delete_work_shift", { "shift_id" => shift_id }).to_json
      end
    end
  end
end
