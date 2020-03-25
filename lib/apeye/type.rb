# frozen_string_literal: true

require 'apeye/definitions/type'
require 'apeye/dsls/type'

module APeye
  class Type
    # Initialize an instance of this type with the value provided
    #
    # @param value [Object, Hash]
    # @return [APeye::Type]
    def initialize(value)
      @value = value
    end

    # Return the raw value object for this type
    #
    # @return [Object, Hash]
    attr_reader :value

    # Generate a hash based on the fields defined in this type
    #
    # @param request [APeye::Request] the associated request
    # @return [Hash]
    def hash(request: nil)
      self.class.definition.fields.each_with_object({}) do |(_, field), hash|
        next unless field.include?(@value, request)

        type_instance = field.value(@value)

        if type_instance.nil?
          # If the value is nil, the value is nil
          value = nil

        elsif type_instance.is_a?(Type)
          next unless type_instance.include?(request)

          # For type values, we want to render a hash
          value = type_instance.hash(request: request)
        else
          # For scaler values, we just want to cast them

          value = type_instance.cast
        end

        hash[field.name.to_s] = value
      end
    end

    # Should this type be included in any output?
    #
    # @param request [APeye::Request]
    # @return [Boolean]
    def include?(request)
      return true if self.class.definition.conditions.empty?

      self.class.definition.conditions.all? do |cond|
        cond.call(@value, request) == true
      end
    end

    class << self
      def define(&block)
        dsl = DSLs::Type.new(definition)
        dsl.instance_eval(&block) if block_given?
        definition
      end

      def create(&block)
        klass = Class.new(self)
        klass.define(&block)
        klass
      end

      def definition
        @definition ||= Definitions::Type.new
      end

      def method_missing(name, *args, &block)
        if definition.dsl.respond_to?(name)
          definition.dsl.send(name, *args, &block)
        else
          super
        end
      end
    end
  end
end
