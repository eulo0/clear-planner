module Ai
  module Tools
    class PlanTasks < Ai::Tools::Base
      desc "Autoschedule the user's UNSCHEDULED tasks into their availability blocks, " \
           "earliest-deadline-first, before each task's due date, as a reviewable draft. " \
           "Use when the user asks to plan their week, schedule their tasks, or fill in " \
           "their schedule. The app does all slot math — you only call this tool."

      param :start_date, type: :string, required: false, desc: "Optional ISO date (YYYY-MM-DD) to plan from; defaults to today"
      param :end_date,   type: :string, required: false, desc: "Optional ISO date (YYYY-MM-DD) to plan until; defaults to the latest task deadline"

      def execute(**args)
        clean = args.transform_keys(&:to_s).compact
        Ai::ToolExecutor.new(Ai.current_context).execute("plan_tasks", clean).to_json
      end
    end
  end
end
