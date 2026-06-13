module Ai
  module Tools
    class EditWorkShift < Ai::Tools::Base
      desc "Edit an existing work shift. Use this when the user asks to change, update, or reschedule a work shift. Only include fields that should be changed."

      param :shift_id,     type: :string,  desc: "The ID of the work shift to edit (can be a draft temp id like d_abc12345)"
      param :title,        type: :string,  required: false, desc: "New title"
      param :start_date,   type: :string,  required: false, desc: "New start date in YYYY-MM-DD format"
      param :start_time,   type: :string,  required: false, desc: "New start time in HH:MM 24-hour format"
      param :end_time,     type: :string,  required: false, desc: "New end time in HH:MM 24-hour format"
      param :description,  type: :string,  required: false, desc: "New description"
      param :location,     type: :string,  required: false, desc: "New location"
      param :color,        type: :string,  required: false, desc: "New hex color like #34D399"
      param :recurring,    type: :boolean, required: false, desc: "Whether the shift repeats weekly"
      param :repeat_days,  type: :array,   required: false, desc: "New weekday numbers: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat"
      param :repeat_until, type: :string,  required: false, desc: "New end date for recurring shifts in YYYY-MM-DD format"

      def execute(shift_id:, **rest)
        args = rest.transform_keys(&:to_s).merge("shift_id" => shift_id)
        Ai::ToolExecutor.new(Ai.current_context).execute("edit_work_shift", args).to_json
      end
    end
  end
end
