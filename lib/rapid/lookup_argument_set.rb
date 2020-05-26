# frozen_string_literal: true

require 'rapid/argument_set'
require 'rapid/definitions/lookup_argument_set'
require 'rapid/lookup_environment'

module Rapid
  class LookupArgumentSet < ArgumentSet

    class << self

      # Return the definition for this argument set
      #
      # @return [Rapid::Definitions::ArgumentSet]
      def definition
        @definition ||= Definitions::LookupArgumentSet.new(Helpers.class_name_to_id(name))
      end

      # Finds all objects referenced by this argument set and add them
      # to the provided set.
      #
      # @param set [Rapid::ObjectSet]
      # @return [void]
      def collate_objects(set)
        super

        definition.potential_errors.each do |error|
          set.add_object(error)
        end
      end

    end

    def resolve
      return if self.class.definition.resolver.nil?
      return @resolved_value if instance_variable_defined?('@resolved_value')

      @resolved_value = environment.call(@request, &self.class.definition.resolver)
    end

    def environment
      @environment ||= LookupEnvironment.new(self)
    end

    def validate(argument, index: nil)
      if @source.empty?
        raise InvalidArgumentError.new(argument, issue: :missing_lookup_value, index: index, path: @path)
      end

      if @source.values.compact.size > 1
        raise InvalidArgumentError.new(argument, issue: :ambiguous_lookup_values, index: index, path: @path)
      end

      true
    end

  end
end
