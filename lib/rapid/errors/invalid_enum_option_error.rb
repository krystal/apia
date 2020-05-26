# frozen_string_literal: true

require 'rapid/errors/runtime_error'

module Rapid
  class InvalidEnumOptionError < Rapid::RuntimeError

    attr_reader :enum
    attr_reader :given_value

    def initialize(enum, given_value)
      @enum = enum
      @given_value = given_value
    end

    def to_s
      "Invalid option for `#{enum.class.definition.name || 'AnonymousEnum'}` (got: #{@given_value.inspect} (#{@given_value.class}))"
    end

  end
end
