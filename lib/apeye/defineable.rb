# frozen_string_literal: true

module APeye
  module Defineable
    def define(&block)
      definition.dsl.instance_eval(&block) if block_given?
      definition
    end

    def create(&block)
      klass = Class.new(self)
      klass.define(&block)
      klass
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