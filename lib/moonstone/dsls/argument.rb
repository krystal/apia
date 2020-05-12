# frozen_string_literal: true

module Moonstone
  module DSLs
    class Argument
      def initialize(definition)
        @definition = definition
      end

      def validation(name, &block)
        @definition.validations << { name: name, block: block }
      end

      def required(value)
        @definition.options[:required] = value
      end

      def condition(&block)
        @definition.options[:condition] = block
      end

      def description(description)
        @definition.options[:description] = description
      end
    end
  end
end