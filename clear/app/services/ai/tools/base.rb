module Ai
  module Tools
    class Base < RubyLLM::Tool
      def name
        self.class.name.demodulize.underscore
      end
    end
  end
end
