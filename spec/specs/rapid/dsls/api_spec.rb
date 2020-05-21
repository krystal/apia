# frozen_string_literal: true

require 'spec_helper'
require 'rapid/dsls/api'
require 'rapid/definitions/api'

describe Rapid::DSLs::API do
  subject(:api) { Rapid::Definitions::API.new('TestAPI') }
  subject(:dsl) { Rapid::DSLs::API.new(api) }

  context '#name' do
    it 'should define the name' do
      dsl.name 'My API'
      expect(api.name).to eq 'My API'
    end
  end

  context '#description' do
    it 'should set the description' do
      dsl.description 'Some description here'
      expect(api.description).to eq 'Some description here'
    end
  end

  context '#authenticator' do
    it 'should allow authenticators to be defined' do
      authenticator = Rapid::Authenticator.create('ExampleAuthenticator')
      dsl.authenticator authenticator
      expect(api.authenticator).to eq authenticator
    end

    it 'should allow an anonymous authenticator to be added' do
      dsl.authenticator do
        name 'My test auth'
        type :bearer
      end
      expect(api.authenticator.definition.id).to eq 'TestAPI/Authenticator'
      expect(api.authenticator.definition.name).to eq 'My test auth'
    end

    it 'should allow an authenticator to be named inline' do
      dsl.authenticator 'MainAuthenticator' do
        name 'Another test'
      end
      expect(api.authenticator.definition.id).to eq 'TestAPI/MainAuthenticator'
      expect(api.authenticator.definition.name).to eq 'Another test'
    end
  end

  context '#controller' do
    it 'should be able to add a controller' do
      controller = Rapid::Controller.create('UsersController')
      dsl.controller :users, controller
      expect(api.controllers[:users]).to eq controller
    end
  end
end