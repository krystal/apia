# frozen_string_literal: true

require 'spec_helper'
require 'apia/request_environment'
require 'rack/mock'

describe Apia::RequestEnvironment do
  def setup_api
    request = Apia::Request.new(Rack::MockRequest.env_for('/', 'CONTENT_TYPE' => 'application/json', :input => '{"name":"Phillip"}'))

    request.api = Apia::API.create('ExampleAPI')
    request.endpoint = Apia::Endpoint.create('ExampleEndpoint')
    request.controller = Apia::Controller.create('ExampleController')

    yield request if block_given?

    response = Apia::Response.new(request, request.endpoint)
    described_class.new(request, response)
  end

  context '#call' do
    it 'should execute the given block' do
      executed = false
      environment = setup_api
      environment.call { executed = true }
      expect(executed).to be true
    end

    it 'should receive any arguments given to it' do
      executed = false
      environment = setup_api
      environment.call(1234) { |_, _, value| executed = value }
      expect(executed).to eq 1234
    end

    it 'should translate known exceptions into appropriate error classes' do
      error_class = Class.new(StandardError)
      environment = setup_api
      environment.request.endpoint.potential_error 'ExampleError' do
        code :example_error
        catch_exception error_class do |fields, exception|
          fields[:field_value] = exception.message
        end
      end

      expect do
        environment.call { raise(error_class, 'Example error string!') }
      end.to raise_error Apia::ErrorExceptionError do |e|
        expect(e.error_class.definition.code).to eq :example_error
        expect(e.fields[:field_value]).to eq 'Example error string!'
      end
    end

    it 'should not translate unknown exceptions' do
      error_class = Class.new(StandardError)
      environment = setup_api

      expect do
        environment.call { raise(error_class, 'Example error string!') }
      end.to raise_error error_class, /example error string/i
    end
  end

  context '#helper' do
    it 'calls any helper defined on the controller' do
      environment = setup_api do |req|
        req.controller.helper :test_helper do
          1234
        end
      end

      expect(environment.helper(:test_helper)).to eq 1234
    end

    it 'passes arguments through' do
      environment = setup_api do |req|
        req.controller.helper :test_helper do |*args|
          args
        end
      end

      expect(environment.helper(:test_helper, 1, 2, 3, 4, 5)).to eq [1, 2, 3, 4, 5]
    end

    it 'raises an error if no helper has been registered' do
      environment = setup_api
      expect { environment.helper(:test_helper) }.to raise_error Apia::InvalidHelperError
    end

    it 'has access to the request and respoinse' do
      environment = setup_api do |req|
        req.controller.helper :test_helper do
          [request, response]
        end
      end

      result = environment.helper(:test_helper)
      expect(result[0]).to be_a Apia::Request
      expect(result[1]).to be_a Apia::Response
    end
  end

  context '#raise_error' do
    it 'should raise an error by name within the same endpoint' do
      environment = setup_api
      environment.request.endpoint.potential_error 'ExampleError' do
        code :example_error
        http_status 417
      end

      expect { environment.raise_error('ExampleEndpoint/ExampleError') }.to raise_error Apia::ErrorExceptionError do |e|
        expect(e.error_class.definition.http_status).to eq 417
        expect(e.error_class.definition.code).to eq :example_error
      end

      expect { environment.raise_error('ExampleError') }.to raise_error Apia::ErrorExceptionError do |e|
        expect(e.error_class.definition.http_status).to eq 417
        expect(e.error_class.definition.code).to eq :example_error
      end
    end

    it 'should raise an error by name within the active authenticator' do
      environment = setup_api
      environment.request.authenticator = Apia::Authenticator.create('MainAuthenticator') do
        potential_error 'AuthError' do
          http_status 403
          code :auth_error
        end
      end

      expect { environment.raise_error('MainAuthenticator/AuthError') }.to raise_error Apia::ErrorExceptionError do |e|
        expect(e.error_class.definition.http_status).to eq 403
        expect(e.error_class.definition.code).to eq :auth_error
      end

      expect { environment.raise_error('AuthError') }.to raise_error Apia::ErrorExceptionError do |e|
        expect(e.error_class.definition.http_status).to eq 403
        expect(e.error_class.definition.code).to eq :auth_error
      end
    end

    it 'should raise an error when given the error class' do
      error = Apia::Error.create('DefinedError') do
        http_status 422
        code :defined_error
      end
      environment = setup_api
      expect { environment.raise_error(error) }.to raise_error Apia::ErrorExceptionError do |e|
        expect(e.error_class.definition.http_status).to eq 422
        expect(e.error_class.definition.code).to eq :defined_error
      end
    end
  end

  context '#error_for_exception' do
    it 'should return nil if no potential error in either the authenticator or endpoint defines it can handle it' do
      environment = setup_api
      example_error = Class.new(StandardError)
      expect(environment.error_for_exception(example_error)).to be nil
    end

    it 'should return the class object for a given exception' do
      example_error = Class.new(StandardError)
      environment = setup_api
      environment.request.endpoint.potential_error 'ExampleError' do
        code :example_error
        catch_exception example_error
      end
      expect(environment.error_for_exception(example_error)).to_not be_nil
      expect(environment.error_for_exception(example_error)[:error].ancestors).to include Apia::Error
      expect(environment.error_for_exception(example_error)[:error].definition.code).to eq :example_error
    end
  end

  context '#paginate' do
    it 'should raise an error if no pagination has been configured for the endpoint' do
      environment = setup_api
      expect { environment.paginate(PaginatedSet.new(10)) }.to raise_error Apia::RuntimeError, /no pagination has been configured/
    end

    subject(:environment) do
      environment = setup_api
      environment.request.endpoint.field :widgets, type: [:string], paginate: true
      environment
    end

    it 'should work for the first page in the set' do
      set = PaginatedSet.new(101)
      environment.paginate(set)
      expect(environment.response.fields[:pagination][:current_page]).to eq 1
      expect(environment.response.fields[:pagination][:total]).to eq 101
      expect(environment.response.fields[:pagination][:total_pages]).to eq 4
      expect(environment.response.fields[:pagination][:large_set]).to be false
      expect(environment.response.fields[:widgets].size).to eq 30
      expect(environment.response.fields[:widgets].first).to eq 's1'
      expect(environment.response.fields[:widgets].last).to eq 's30'
    end

    it 'should work for subsequent pages' do
      environment.request.arguments[:page] = 2
      set = PaginatedSet.new(101)
      environment.paginate(set)
      expect(environment.response.fields[:pagination][:current_page]).to eq 2
      expect(environment.response.fields[:pagination][:per_page]).to eq 30
      expect(environment.response.fields[:pagination][:total]).to eq 101
      expect(environment.response.fields[:pagination][:total_pages]).to eq 4
      expect(environment.response.fields[:pagination][:large_set]).to be false
      expect(environment.response.fields[:widgets].size).to eq 30
      expect(environment.response.fields[:widgets].first).to eq 's31'
      expect(environment.response.fields[:widgets].last).to eq 's60'
    end

    it 'should work with an incomplete last page' do
      environment.request.arguments[:page] = 3
      set = PaginatedSet.new(66)
      environment.paginate(set)
      expect(environment.response.fields[:pagination][:current_page]).to eq 3
      expect(environment.response.fields[:pagination][:per_page]).to eq 30
      expect(environment.response.fields[:pagination][:total]).to eq 66
      expect(environment.response.fields[:pagination][:total_pages]).to eq 3
      expect(environment.response.fields[:pagination][:large_set]).to be false
      expect(environment.response.fields[:widgets].size).to eq 6
      expect(environment.response.fields[:widgets].first).to eq 's61'
      expect(environment.response.fields[:widgets].last).to eq 's66'
    end

    it 'should work with large sets' do
      set = PaginatedSet.new(1010)
      environment.paginate(set, potentially_large_set: true)
      expect(environment.response.fields[:pagination][:current_page]).to eq 1
      expect(environment.response.fields[:pagination][:per_page]).to eq 30
      expect(environment.response.fields[:pagination][:total]).to be nil
      expect(environment.response.fields[:pagination][:total_pages]).to be nil
      expect(environment.response.fields[:pagination][:large_set]).to be true
      expect(environment.response.fields[:widgets].size).to eq 30
      expect(environment.response.fields[:widgets].first).to eq 's1'
      expect(environment.response.fields[:widgets].last).to eq 's30'
    end

    it 'should work with large sets (when they arent actually large)' do
      set = PaginatedSet.new(20)
      environment.paginate(set, potentially_large_set: true)
      expect(environment.response.fields[:pagination][:current_page]).to eq 1
      expect(environment.response.fields[:pagination][:per_page]).to eq 30
      expect(environment.response.fields[:pagination][:total]).to be 20
      expect(environment.response.fields[:pagination][:total_pages]).to be 1
      expect(environment.response.fields[:pagination][:large_set]).to be false
      expect(environment.response.fields[:widgets].size).to eq 20
      expect(environment.response.fields[:widgets].first).to eq 's1'
      expect(environment.response.fields[:widgets].last).to eq 's20'
    end

    it 'should work with custom page sizes' do
      environment.request.arguments[:per_page] = 50
      set = PaginatedSet.new(205)
      environment.paginate(set)
      expect(environment.response.fields[:pagination][:current_page]).to eq 1
      expect(environment.response.fields[:pagination][:per_page]).to eq 50
      expect(environment.response.fields[:pagination][:total]).to be 205
      expect(environment.response.fields[:pagination][:total_pages]).to be 5
      expect(environment.response.fields[:pagination][:large_set]).to be false
      expect(environment.response.fields[:widgets].size).to eq 50
      expect(environment.response.fields[:widgets].first).to eq 's1'
      expect(environment.response.fields[:widgets].last).to eq 's50'
    end
  end

  context '#cors' do
    subject(:environment) { setup_api }

    it 'returns a CORS instance' do
      expect(environment.cors).to be_a Apia::CORS
    end
  end
end
