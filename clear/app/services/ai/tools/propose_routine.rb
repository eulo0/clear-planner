module Ai
  module Tools
    class ProposeRoutine < Ai::Tools::Base
      desc "Propose a recurring weekly availability-block routine (study/deep-work/errand time windows) " \
           "for the user to review. Use when the user asks to set up their week, build a study routine, " \
           "or create their schedule structure. Provide INTENT ONLY (hours and preferences) — never times; " \
           "the app lays out the actual non-conflicting blocks."

      param :study_hours_per_week,     type: :integer, required: false, desc: "Target study hours per week"
      param :deep_work_hours_per_week, type: :integer, required: false, desc: "Target deep-work/focus hours per week"
      param :errand_hours_per_week,    type: :integer, required: false, desc: "Target errand/admin hours per week"
      param :preferred_dayparts,       type: :array,   required: false, desc: "Any of: morning, afternoon, evening"
      param :keep_free,                type: :array,   required: false, desc: "Weekday names to leave entirely free, e.g. [\"sunday\"]"
      param :avoid,                    type: :array,   required: false, desc: "Free-form hints, e.g. [\"before_9am\"]"

      def execute(**args)
        clean = args.transform_keys(&:to_s).compact
        Ai::ToolExecutor.new(Ai.current_context).execute("propose_routine", clean).to_json
      end
    end
  end
end
