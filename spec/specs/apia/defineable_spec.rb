# frozen_string_literal: true

require 'spec_helper'
require 'apia/defineable'

describe Apia::Defineable do
  # We'll test this using `API` but it could be any object that
  # extends Defineable.
  context 'IDs' do
    it 'should not be allowed to be created without an ID' do
      expect do
        Apia::API.create
      end.to raise_error(ArgumentError, /wrong number of argument/)
    end

    it 'should have an ID with the value given when creating if anonymous' do
      klass = Apia::API.create('Example')
      expect(klass.definition.id).to eq 'Example'
    end

    it 'should have an ID prefixed with the container ID if a nested anonymous' do
      api = Apia::API.create('ExampleAPI') do
        authenticator 'MainAuthenticator' do
          type :bearer
        end
      end
      expect(api.definition.id).to eq 'ExampleAPI'
      expect(api.definition.authenticator.definition.id).to eq 'ExampleAPI/MainAuthenticator'
    end

    # rubocop:disable Lint/ConstantDefinitionInBlock:
    it 'should have an ID with the original class name if defined that way' do
      class ExampleAPI < Apia::API
      end
      expect(ExampleAPI.definition.id).to eq 'ExampleAPI'
    end

    it 'should have an ID with the module' do
      module SomeModule
        class ExampleAPIWithinModule < Apia::API
        end
      end
      expect(SomeModule::ExampleAPIWithinModule.definition.id).to eq 'SomeModule/ExampleAPIWithinModule'
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock:
  end
end
