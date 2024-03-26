# frozen_string_literal: true

require 'json'
require 'apia/rack_error'
require 'apia/request'
require 'apia/response'
require 'apia/notifications'

module Apia
  class Rack

    def initialize(app, api, namespace, **options)
      @app = app
      @api = api
      @namespace = '/' + namespace.sub(/\A\/+/, '').sub(/\/+\z/, '')
      @options = options
    end

    # Is this supposed to be running in development? This will validate the whole
    # API on each request as well as being more verbose about internal server
    # errors that are encountered.
    #
    # @return [Boolean]
    def development?
      env_is_dev = ENV['RACK_ENV'] == 'development'
      return true if env_is_dev && @options[:development].nil?

      @options[:development] == true
    end

    # Parse a given full path and return nil if it doesn't match our
    # namespace or return a hash with the controller and endpoint
    # named as available.
    #
    # @param path [String] /core/v1/controller/endpoint
    # @return [nil, Hash]
    def find_route(method, path)
      return if api.nil?

      api.definition.route_set.find(method.to_s.downcase.to_sym, path).first
    end

    # Return the API object
    #
    # @return [Apia::API]
    def api
      return Object.const_get(@api) if @api.is_a?(String) && development?
      return @cached_api ||= Object.const_get(@api) if @api.is_a?(String)

      @api
    end

    # Actually make the request
    #
    # @param env [Hash]
    # @return [Array] a rack triplet
    def call(env)
      if @options[:hosts]&.none? { |host| host == env['HTTP_HOST'] }
        return @app.call(env)
      end

      unless env['PATH_INFO'] =~ /\A#{Regexp.escape(@namespace)}\/([a-z].*)\z/i
        return @app.call(env)
      end

      api_path = Regexp.last_match(1)

      handle_request(env, api_path)
    end

    private

    def handle_request(env, api_path)
      request = nil
      request_method = env['REQUEST_METHOD'].upcase
      notify_hash = { api: api, env: env, path: api_path, method: request_method }

      Apia::Notifications.notify(:request_start, notify_hash)

      validate_api if development?

      access_control_request_method = env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']&.upcase if request_method == 'OPTIONS'
      route = find_route((access_control_request_method || request_method), api_path)
      if route.nil?
        Apia::Notifications.notify(:request_route_not_found, notify_hash)
        raise RackError.new(404, 'route_not_found', "No route matches '#{api_path}' for #{request_method}")
      end

      request = Apia::Request.new(env)
      request.api_path = api_path
      request.namespace = @namespace
      request.api = api
      request.controller = route.controller
      request.endpoint = route.endpoint
      request.route = route

      Apia::Notifications.notify(:request_before_execution, notify_hash.merge(request: request))

      start_time = Time.now
      response = request.endpoint.execute(request)
      end_time = Time.now
      time = end_time - start_time

      Apia::Notifications.notify(:request, notify_hash.merge(request: request, response: response, time: time))

      response.rack_triplet
    rescue ::StandardError => e
      handle_error(e, env, request, request_method)
    ensure
      Apia::Notifications.notify(:request_end, notify_hash)
    end

    def handle_error(exception, env, request, request_method)
      notify_hash = { api: api, env: env, path: request&.api_path, request: request, method: request_method, exception: exception }

      if exception.is_a?(RackError) || exception.is_a?(Apia::ManifestError)
        Apia::Notifications.notify(:request_manifest_error, notify_hash)
        return exception.triplet
      end

      api.definition.exception_handlers.call(exception, {
        env: env,
        api: api,
        request: request
      })

      Apia::Notifications.notify(:request_error, notify_hash)

      if development?
        return triplet_for_exception(exception)
      end

      self.class.error_triplet('unhandled_exception', status: 500)
    end

    def validate_api
      api.validate_all.raise_if_needed
    end

    def triplet_for_exception(exception)
      self.class.error_triplet(
        'unhandled_exception',
        description: 'This is an exception that has occurred and not been handled.',
        detail: {
          class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace
        },
        status: 500
      )
    end

    class << self

      # Return a plain text triplet for the given body.
      #
      # @param body [String]
      # @param status [Integer]
      # @param headers [Hash]
      # @return [Array]
      def plain_triplet(body, status: 200, headers: {})
        response_triplet(body, content_type: 'text/plain', status: status, headers: headers)
      end

      # Return a JSON-ready triplet for the given body.
      #
      # @param body [Hash, Array]
      # @param status [Integer]
      # @param headers [Hash]
      # @return [Array]
      def json_triplet(body, status: 200, headers: {})
        response_triplet(body.to_json, content_type: 'application/json', status: status, headers: headers)
      end

      # Return a triplet for the given body.
      #
      # @param body [Hash, Array]
      # @param content_type [String]
      # @param status [Integer]
      # @param headers [Hash]
      # @return [Array]
      def response_triplet(body, content_type:, status: 200, headers: {})
        [
          status,
          headers.merge('content-type' => content_type, 'content-length' => body.bytesize.to_s),
          [body]
        ]
      end

      # Return a triplet for a given error using the standard error schema
      #
      # @param code [String]
      # @param description [String]
      # @param detail [Hash]
      # @param status [Integer]
      # @param headers [Hash]
      # @return [Array]
      def error_triplet(code, description: nil, detail: {}, status: 500, headers: {})
        json_triplet({
                       error: {
                         code: code,
                         description: description,
                         detail: detail
                       }
                     }, status: status, headers: headers.merge('x-api-schema' => 'json-error'))
      end

    end

  end
end
