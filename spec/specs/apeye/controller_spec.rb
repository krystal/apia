# frozen_string_literal: true

require 'spec_helper'
require 'apeye/controller'
require 'apeye/endpoint'

describe APeye::Controller do
  context '.description' do
    it 'should allow the description to be defined' do
      type = APeye::Controller.create('ExampleController') do
        description 'Some description goes here...'
      end
      expect(type.definition.description).to eq 'Some description goes here...'
    end
  end

  context '.authenticator' do
    it 'should allow you to define an authenticator' do
      authenticator = APeye::Authenticator.new
      controller = APeye::Controller.create('ExampleController')
      controller.authenticator authenticator
      expect(controller.definition.authenticator).to eq authenticator
    end

    it 'should allow you to define an endpoint' do
      create_endpoint = APeye::Endpoint.create('ExampleEndpoint')
      controller = APeye::Controller.create('ExampleController')
      controller.endpoint :create, create_endpoint
      expect(controller.definition.endpoints[:create]).to eq create_endpoint
    end

    it 'should allow you to define an anonymous endpoint' do
      controller = APeye::Controller.create('UserController') do
        endpoint :create do
          description 'Example description'
        end
      end
      expect(controller.definition.name).to eq 'UserController'
      expect(controller.definition.endpoints[:create].definition.name).to eq 'UserController.create'
      expect(controller.definition.endpoints[:create].definition.description).to eq 'Example description'
    end
  end
end