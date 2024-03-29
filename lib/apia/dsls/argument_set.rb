# frozen_string_literal: true

require 'apia/dsl'
require 'apia/definitions/argument'
require 'apia/helpers'

module Apia
  module DSLs
    class ArgumentSet < DSL

      def argument(name, *args, type: nil, **options, &block)
        type = args[0] if type.nil?

        argument = Definitions::Argument.new(name, id: "#{@definition.id}/#{Helpers.camelize(name.to_s)}Argument")

        if type.is_a?(Array)
          argument.type = type[0]
          argument.array = true
        else
          argument.type = type
          argument.array = false
        end

        argument.required = options[:required] if options.key?(:required)
        argument.default = options[:default] if options.key?(:default)
        argument.description = options[:description] if options.key?(:description)

        argument.dsl.instance_eval(&block) if block_given?

        @definition.arguments[name.to_sym] = argument
      end

    end
  end
end
