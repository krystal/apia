# frozen_string_literal: true

module APeye
  module DSLs
    class Argument
      def initialize(argument)
        @argument = argument
      end

      def validation(&block)
        @argument.options[:validation] = block
      end

      def required(value)
        @argument.options[:required] = value
      end

      def condition(&block)
        @argument.options[:condition] = block
      end
    end
  end
end