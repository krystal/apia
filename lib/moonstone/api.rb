# frozen_string_literal: true

require 'moonstone/defineable'
require 'moonstone/definitions/api'
require 'moonstone/object_set'
require 'moonstone/manifest_errors'

module Moonstone
  class API
    extend Defineable

    def self.definition
      @definition ||= Definitions::API.new(name&.split('::')&.last)
    end

    def self.objects
      set = ObjectSet.new([self])
      set.add_object(definition.authenticator) if definition.authenticator
      definition.controllers.values.each { |con| set.add_object(con) }
      set
    end

    # Validate all objects in the API and return them
    #
    # @return [Moonstone::ManifestErrors]
    def self.validate_all
      errors = ManifestErrors.new
      objects.each do |object|
        next unless object.respond_to?(:definition)

        object.definition.validate(errors)
      end
      errors
    end
  end
end
