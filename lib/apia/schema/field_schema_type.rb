# frozen_string_literal: true

require 'apia/object'
require 'apia/schema/field_spec_options_schema_type'

module Apia
  module Schema
    class FieldSchemaType < Apia::Object

      no_schema

      field :id, type: :string
      field :name, type: :string
      field :description, type: :string, null: true
      field :type, type: :string do
        backend { |f| f.type.id }
      end
      field :null, type: :boolean do
        backend(&:null?)
      end
      field :array, type: :boolean do
        backend(&:array?)
      end

      field :spec, type: FieldSpecOptionsSchemaType do
        backend do |field|
          hash = {}
          hash[:all] = field.include.nil? || field.include == true
          if field.include.is_a?(String)
            hash[:spec] = field.include
          end
          hash
        end
      end

    end
  end
end
