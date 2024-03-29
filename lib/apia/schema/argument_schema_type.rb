# frozen_string_literal: true

require 'apia/object'

module Apia
  module Schema
    class ArgumentSchemaType < Apia::Object

      no_schema

      field :name, type: :string
      field :description, type: :string, null: true
      field :type, type: :string do
        backend { |f| f.type.id }
      end
      field :required, type: :boolean do
        backend(&:required?)
      end
      field :array, type: :boolean do
        backend(&:array?)
      end
      field :default, type: :string, null: true do
        backend { |o| o.default&.to_s }
      end

    end
  end
end
