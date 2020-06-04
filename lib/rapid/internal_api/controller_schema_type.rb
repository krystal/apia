# frozen_string_literal: true

require 'rapid/object'
require 'rapid/internal_api/authenticator_schema_type'
require 'rapid/internal_api/controller_endpoint_schema_type'

module Rapid
  module InternalAPI
    class ControllerSchemaType < Rapid::Object

      no_schema

      field :id, type: :string
      field :name, type: :string, null: true
      field :description, type: :string, null: true
      field :authenticator, type: :string, null: true do
        backend { |c| c.authenticator&.definition&.id }
      end
      field :endpoints, type: [ControllerEndpointSchemaType] do
        backend do |c|
          c.endpoints.map do |key, endpoint|
            {
              name: key.to_s,
              endpoint: endpoint.definition.id
            }
          end
        end
      end

    end
  end
end
