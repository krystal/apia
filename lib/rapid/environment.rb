# frozen_string_literal: true

module Rapid
  # This is the environment/scope that all actions are executed within. It is purely here
  # to provide access to some helper methods.
  class Environment

    def initialize(request)
      @request = request
    end

    def call(response, &block)
      return unless block_given?

      instance_exec(@request, response, &block)
    end

    # Raise an error
    #
    # @param error [String, Class] an error class or the name of a defined error
    def raise_error(error, fields = {})
      if error.respond_to?(:ancestors) && error.ancestors.include?(Rapid::Error)
        raise error.exception(fields)
      elsif found_error = find_error_by_name(error)
        raise found_error.exception(fields)
      else
        raise Rapid::RuntimeError, "No error defined named #{error}"
      end
    end

    private

    def find_error_by_name(error_name)
      @request.authenticator&.definition&.potential_errors&.find { |e| e.definition.id == error_name } ||
        @request.endpoint&.definition&.potential_errors&.find { |e| e.definition.id == error_name }
    end

  end
end