# frozen_string_literal: true

require 'apia/defineable'
require 'apia/definitions/argument_set'
require 'apia/errors/invalid_argument_error'
require 'apia/errors/missing_argument_error'
require 'apia/helpers'
require 'apia/deep_merge'

module Apia
  class ArgumentSet

    # This is a constant that represents a missing value where `nil` means
    # the user actually wanted to send null/nil.
    class MissingValue

      def self.singleton
        @singleton ||= new
      end

    end

    extend Defineable

    class << self

      # Return the definition for this argument set
      #
      # @return [Apia::Definitions::ArgumentSet]
      def definition
        @definition ||= Definitions::ArgumentSet.new(Helpers.class_name_to_id(name))
      end

      # Finds all objects referenced by this argument set and add them
      # to the provided set.
      #
      # @param set [Apia::ObjectSet]
      # @return [void]
      def collate_objects(set)
        definition.arguments.each_value do |argument|
          set.add_object(argument.type.klass) if argument.type.usable_for_argument?
        end
      end

      # Create a new argument set from a request object
      #
      # @param request [Apia::Request]
      # @return [Apia::ArgumentSet]
      def create_from_request(request)
        json_body = request.json_body || {}
        params = request.params || {}
        merged_params = DeepMerge.merge(params, json_body)

        new(merged_params, request: request)
      end

    end

    # Create a new argument set by providing a hash containing the raw
    # arguments
    #
    # @param hash [Hash]
    # @param path [Array]
    # @return [Apia::ArgumentSet]
    def initialize(hash, path: [], request: nil)
      unless hash.is_a?(Hash)
        raise Apia::RuntimeError, 'Hash was expected for argument'
      end

      @path = path
      @request = request
      @source = self.class.definition.arguments.each_with_object({}) do |(arg_key, argument), source|
        given_value = lookup_value(hash, arg_key, argument, request)

        if argument.required? && (given_value.nil? || given_value.is_a?(MissingValue))
          raise MissingArgumentError.new(argument, path: @path + [argument])
        end

        # If the given value is missing, we'll just skip adding this to the hash
        next if given_value.is_a?(MissingValue)

        given_value = parse_value(argument, given_value)
        validation_errors = argument.validate_value(given_value)
        unless validation_errors.empty?
          raise InvalidArgumentError.new(argument, issue: :validation_errors, errors: validation_errors, path: @path + [argument])
        end

        source[argument.name.to_sym] = given_value
      end
    end

    # Return an item from the argument set
    #
    # @param value [String, Symbol]
    # @return [Object, nil]
    def [](value)
      @source[value.to_sym]
    end

    # Return an item from this argument set
    #
    # @param values [Array<String, Symbol>]
    # @return [Object, nil]
    def dig(*values)
      @source.dig(*values)
    end

    # Return the source object
    #
    # @return [Hash]
    def to_hash
      @source.transform_values do |value|
        value.is_a?(ArgumentSet) ? value.to_hash : value
      end
    end

    # Return whether an argument has been provided or not?
    #
    # @param name [Symbol]
    # @return [Boolean]
    def has?(key)
      @source.key?(key.to_sym)
    end

    # Return whether the argument set has no arguments within?
    #
    # @return [Boolean]
    def empty?
      @source.empty?
    end

    # Validate an argument set and return any errors as appropriate
    #
    # @param argument [Apia::Argument]
    def validate(argument, index: nil)
    end

    private

    def lookup_value(hash, key, argument, request)
      if hash.key?(key.to_s)
        hash[key.to_s]
      elsif hash.key?(key.to_sym)
        hash[key.to_sym]
      else
        route_value = value_from_route(argument, request)
        return route_value unless route_value.is_a?(MissingValue)
        return argument.default unless argument.default.nil?

        MissingValue.singleton
      end
    end

    def parse_value(argument, value, index: nil, in_array: false)
      if value.nil?
        nil

      elsif argument.array? && value.is_a?(Array)
        value.each_with_index.map do |v, i|
          parse_value(argument, v, index: i, in_array: true)
        end

      elsif argument.array? && !in_array
        raise InvalidArgumentError.new(argument, issue: :array_expected, index: index, path: @path + [argument])

      elsif argument.type.scalar?
        begin
          type = argument.type.klass.parse(value)
        rescue Apia::ParseError => e
          # If we cannot parse the given input, this is cause for a parse error to be raised.
          raise InvalidArgumentError.new(argument, issue: :parse_error, errors: [e.message], index: index, path: @path + [argument])
        end

        unless argument.type.klass.valid?(type)
          # If value we have parsed is not actually valid, we 'll raise an argument error.
          # In most cases, it is likely that an integer has been provided to string etc...
          raise InvalidArgumentError.new(argument, issue: :invalid_scalar, index: index, path: @path + [argument])
        end

        type

      elsif argument.type.argument_set?
        unless value.is_a?(Hash)
          raise InvalidArgumentError.new(argument, issue: :object_expected, index: index, path: @path + [argument])
        end

        value = argument.type.klass.new(value, path: @path + [argument], request: @request)
        value.validate(argument, index: index)
        value

      elsif argument.type.enum?
        unless argument.type.klass.definition.values[value]
          raise InvalidArgumentError.new(argument, issue: :invalid_enum_value, index: index, path: @path + [argument])
        end

        value
      end
    end

    def check_for_missing_required_arguments
      self.class.definition.arguments.each_value do |arg|
        next unless arg.required?
        next if self[arg.name]
      end
    end

    def value_from_route(argument, request)
      return MissingValue.singleton if request.nil?
      return MissingValue.singleton if request.route.nil?

      route_args = request.route.extract_arguments(request.api_path)
      unless route_args.key?(argument.name.to_s)
        return MissingValue.singleton
      end

      value_for_arg = route_args[argument.name.to_s]
      return nil if value_for_arg.nil?

      if argument.type.argument_set?
        # If the argument is an argument set, we'll just want to try and
        # populate the first argument.
        if first_arg = argument.type.klass.definition.arguments.keys.first
          { first_arg.to_s => value_for_arg }
        else
          {}
        end
      else
        value_for_arg
      end
    end

  end
end
