# frozen_string_literal: true

require 'json'
require 'apia/rack'

module Apia
  class Response

    TYPES = [
      JSON = :json,
      PLAIN = :plain
    ].freeze

    attr_accessor :status
    attr_reader :fields
    attr_reader :headers
    attr_writer :body

    def initialize(request, endpoint)
      @request = request
      @endpoint = endpoint

      @status = @endpoint.definition.http_status_code
      @fields = {}
      @headers = {}
    end

    def plain!
      @type = PLAIN
      @body = ''
    end

    # Add a field value for this endpoint
    #
    # @param name [Symbol]
    # @param value [Hash, Object, nil]
    # @return [void]
    def add_field(name, value)
      @fields[name.to_sym] = value
    end

    # Add a header to the response
    #
    # @param name [String]
    # @param value [String]
    # @return [void]
    def add_header(name, value)
      @headers[name.to_s] = value&.to_s
    end

    # Return the full hash of data that should be returned for this
    # request.
    #
    # @return [Hash]
    def hash
      @hash ||= @endpoint.definition.fields.generate_hash(@fields, request: @request)
    end

    # Return the body that should be returned for this response
    #
    # @return [Hash]
    def body
      @body || hash
    end

    def type
      @type || JSON
    end

    # Return the rack triplet for this response
    #
    # @return [Array]
    def rack_triplet
      case type
      when JSON
        Rack.json_triplet(body, headers: headers, status: status)
      when PLAIN
        Rack.plain_triplet(body, headers: headers, status: status)
      end
    end

  end
end
