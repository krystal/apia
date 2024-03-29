# frozen_string_literal: true

require 'apia/errors/runtime_error'

module Apia
  class InvalidJSONError < Apia::RuntimeError

    def http_status
      400
    end

    def hash
      {
        code: 'invalid_json_body',
        description: 'The JSON body provided with this request is invalid',
        detail: {
          details: message
        }
      }
    end

  end
end
