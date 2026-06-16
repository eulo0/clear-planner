module Ai
  module Tools
    class CreateWorkShift < Ai::Tools::Base
      desc "Create a new work shift on the user's schedule. Use this when the user asks to add or schedule a work shift or job shift."

      param :title,        type: :string,  desc: "Title/name of the shift (e.g. 'Work', 'Barista shift')"
      param :start_date,   type: :string,  desc: "Start date in YYYY-MM-DD format"
      param :start_time,   type: :string,  desc: "Shift start time in HH:MM 24-hour format (e.g. '09:00')"
      param :end_time,     type: :string,  desc: "Shift end time in HH:MM 24-hour format (e.g. '17:00')"
      param :description,  type: :string,  required: false, desc: "Optional description or notes"
      param :location,     type: :string,  required: false, desc: "Optional location"
      param :color,        type: :string,  required: false, desc: "Optional hex color like #34D399"
      param :recurring,    type: :boolean, required: false, desc: "Whether the shift repeats weekly (default true)"
      param :repeat_days,  type: :array,   required: false, desc: "Weekday numbers: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat. Required if recurring is true."
      param :repeat_until, type: :string,  required: false, desc: "Optional end date for recurring shifts in YYYY-MM-DD format"

      def execute(title:, start_date:, start_time:, end_time:, **rest)
        args = rest.transform_keys(&:to_s).merge(
          "title" => title, "start_date" => start_date,
          "start_time" => start_time, "end_time" => end_time
        )
        Ai::ToolExecutor.new(Ai.current_context).execute("create_work_shift", args).to_json
      end
    end
  end
end
