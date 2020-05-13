# frozen_string_literal: true

require 'moonstone/type'
require 'moonstone/internal_api/authenticator_schema_type'
require 'moonstone/internal_api/controller_endpoint_schema_type'

module Moonstone
  module InternalAPI
    class ControllerSchemaType < Moonstone::Type
      field :id, type: :string
      field :description, type: :string, nil: true
      field :authenticator, type: AuthenticatorSchemaType, nil: true do
        backend { |c| c.authenticator&.definition }
      end
      field :endpoints, type: [ControllerEndpointSchemaType] do
        backend do |c|
          c.endpoints.map do |key, endpoint|
            {
              name: key.to_s,
              endpoint: endpoint.definition
            }
          end
        end
      end
    end
  end
end
