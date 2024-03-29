# frozen_string_literal: true

require 'spec_helper'
require 'apia/dsls/endpoint'
require 'apia/definitions/endpoint'
require 'apia/authenticator'

describe Apia::DSLs::Endpoint do
  subject(:endpoint) { Apia::Definitions::Endpoint.new('TestEndpoint') }
  subject(:dsl) { Apia::DSLs::Endpoint.new(endpoint) }

  include_examples 'has fields dsl' do
    subject(:definition) { endpoint }
  end

  context '#name' do
    it 'should set the name' do
      dsl.name 'My endpoint'
      expect(endpoint.name).to eq 'My endpoint'
    end
  end

  context '#description' do
    it 'should set the description' do
      dsl.description 'Create user desc'
      expect(endpoint.description).to eq 'Create user desc'
    end
  end

  context '#authenticator' do
    it 'should set the authenticator' do
      authenticator = Apia::Authenticator
      dsl.authenticator authenticator
      expect(endpoint.authenticator).to eq authenticator
    end

    it 'should be able to define an inline authenticator' do
      dsl.authenticator do
        name 'Authenticator for thing'
      end
      expect(endpoint.authenticator.definition.id).to eq 'TestEndpoint/Authenticator'
      expect(endpoint.authenticator.definition.name).to eq 'Authenticator for thing'
    end

    it 'should be able to define an inline authenticator with a name' do
      dsl.authenticator('CustomAuth') {}
      expect(endpoint.authenticator.definition.id).to eq 'TestEndpoint/CustomAuth'
    end
  end

  context '#potential_error' do
    it 'should set potential errors' do
      error = Apia::Error.create('MyError')
      dsl.potential_error error
      expect(endpoint.potential_errors.size).to eq 1
      expect(endpoint.potential_errors.first).to eq error
    end

    it 'should allow errors to be defined inline' do
      dsl.potential_error 'ExampleError' do
        code :some_error
      end
      expect(endpoint.potential_errors.size).to eq 1
      expect(endpoint.potential_errors.first.definition.id).to eq 'TestEndpoint/ExampleError'
      expect(endpoint.potential_errors.first.definition.code).to eq :some_error
    end
  end

  context '#http_status' do
    it 'should set the HTTP status' do
      dsl.http_status 202
      expect(endpoint.http_status).to eq 202
    end
  end

  context '#action' do
    it 'should set the action' do
      dsl.action { 1234 }
      expect(endpoint.action.call).to eq 1234
    end
  end

  context '#argument' do
    it 'should add arguments' do
      dsl.argument :name, type: :string
      expect(endpoint.argument_set.definition.arguments[:name]).to_not be nil
      expect(endpoint.argument_set.definition.arguments[:name]).to be_a Apia::Definitions::Argument
    end
  end

  context '#field' do
    context 'when an existing fieldset has been provided' do
      it 'raises an error if another field is defined' do
        dsl.fields Apia::FieldSet.new
        expect { dsl.field :name, type: :string }.to raise_error Apia::StandardError
      end
    end

    context 'when paginated' do
      it 'should add a `page` argument' do
        dsl.field :widgets, type: [:string], paginate: true
        expect(endpoint.argument_set.definition.arguments[:page]).to be_a Apia::Definitions::Argument
        expect(endpoint.argument_set.definition.arguments[:page].type.klass).to eq Apia::Scalars::Integer
        expect(endpoint.argument_set.definition.arguments[:page].required?).to be false
      end

      it 'should add a `per_page` argument' do
        dsl.field :widgets, type: [:string], paginate: true
        expect(endpoint.argument_set.definition.arguments[:per_page]).to be_a Apia::Definitions::Argument
        expect(endpoint.argument_set.definition.arguments[:per_page].type.klass).to eq Apia::Scalars::Integer
        expect(endpoint.argument_set.definition.arguments[:per_page].required?).to be false
      end

      it 'should add a `pagination` field' do
        dsl.field :widgets, type: [:string], paginate: true
        expect(endpoint.fields[:pagination]).to be_a Apia::Definitions::Field
        expect(endpoint.fields[:pagination].type.klass).to eq Apia::PaginationObject
        expect(endpoint.fields[:pagination].null?).to be false
      end

      it 'should set the paginated field' do
        dsl.field :widgets, type: [:string], paginate: true
        expect(endpoint.paginated_field).to eq :widgets
      end

      it 'should raise an error if called twice' do
        dsl.field :widgets, type: [:string], paginate: true
        expect do
          dsl.field :potatos, type: [:string], paginate: true
        end.to raise_error Apia::RuntimeError, /cannot define more than one paginated field/i
      end
    end
  end

  context '#fields' do
    it 'sets the endpoints fieldset to the given field set' do
      fieldset = Apia::FieldSet.new
      dsl.fields fieldset
      expect(endpoint.fields).to eq fieldset
    end

    it 'raises an error if fields have already been defined' do
      dsl.field :example, :string
      expect { dsl.fields Apia::FieldSet.new }.to raise_error Apia::StandardError
    end
  end

  context '#scope' do
    it 'should add a scope' do
      dsl.scope 'example:read'
      expect(endpoint.scopes).to eq ['example:read']
    end

    it 'should not add the same scope twice' do
      dsl.scope 'example:read'
      dsl.scope 'example:read'
      expect(endpoint.scopes).to eq ['example:read']
    end
  end

  context '#scopes' do
    it 'should add multiple scopes' do
      dsl.scopes 'example:read', 'example:write'
      expect(endpoint.scopes).to eq ['example:read', 'example:write']
    end
  end
end
