# frozen_string_literal: true

require 'spec_helper'
require 'apia/rack'
require 'apia/api'
require 'rack/mock'

describe Apia::Rack do
  context '#find_route' do
    subject(:rack) { Apia::Rack.new(nil, nil, '/api/core') }

    it 'should return nil if there is no matching route' do
      expect(rack.find_route(:get, 'missing')).to be_nil
    end

    it 'should return the matching route' do
      api = Apia::API.create('MyAPI') do
        routes do
          get 'widgets'
        end
      end
      rack = Apia::Rack.new(nil, api, '/api/core')
      expect(rack.find_route(:get, 'widgets')).to be_a Apia::Route
    end

    it 'should work when methods are given as strings' do
      api = Apia::API.create('MyAPI') do
        routes do
          get 'widgets'
        end
      end
      rack = Apia::Rack.new(nil, api, '/api/core')
      expect(rack.find_route('GET', 'widgets')).to be_a Apia::Route
    end
  end

  context '#development?' do
    it 'should be false by default' do
      rack = Apia::Rack.new(nil, nil, '/api/core')
      expect(rack.development?).to be false
    end

    it 'should be true if the option is set to true' do
      rack = Apia::Rack.new(nil, nil, '/api/core', development: true)
      expect(rack.development?).to be true
    end

    it 'should be false if the option is set to false' do
      rack = Apia::Rack.new(nil, nil, '/api/core', development: false)
      expect(rack.development?).to be false
    end

    it 'should be true if RACK_ENV is set to development' do
      allow(ENV).to receive(:[]).with('RACK_ENV').and_return 'development'
      rack = Apia::Rack.new(nil, nil, '/api/core')
      expect(rack.development?).to be true
    end

    it 'should be false if RACK_ENV is development but the development option is false' do
      allow(ENV).to receive(:[]).with('RACK_ENV').and_return 'development'
      rack = Apia::Rack.new(nil, nil, '/api/core', development: false)
      expect(rack.development?).to be false
    end
  end

  context '#call' do
    subject(:app) do
      Class.new do
        def call(_env)
          [200, {}, ['Hello world!']]
        end
      end.new
    end

    it 'should return the base application if the namespace does not match' do
      api = Apia::API.create('MyAPI')
      rack = described_class.new(app, api, 'api/v1')
      ['invalid', 'api', 'api/v2'].each do |path|
        env = Rack::MockRequest.env_for(path)
        result = rack.call(env)
        expect(result).to be_a Array
        expect(result[2][0]).to eq 'Hello world!'
      end
    end

    it 'should return the base application if hosts are provided and none of them match' do
      api = Apia::API.create('MyAPI')
      rack = described_class.new(app, api, 'api/v1', hosts: ['api.example.com'])
      ['blah.com', 'example.com', 'api.something.com'].each do |host|
        env = Rack::MockRequest.env_for('/api/v1', 'HTTP_HOST' => host)
        result = rack.call(env)
        expect(result).to be_a Array
        expect(result[2][0]).to eq 'Hello world!'
      end
    end

    it 'should allow requests with matching hostnames through' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action do
            response.add_header 'x-demo', 'hello'
          end
        end
      end
      api = Apia::API.create('MyAPI') do
        routes do
          get 'test', controller: controller, endpoint: :test
        end
      end
      rack = described_class.new(app, api, 'api/v1', hosts: ['api.example.com'])
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test', 'HTTP_HOST' => 'api.example.com'))
      expect(result).to be_a Array
      expect(result[1]['x-demo']).to eq 'hello'
    end

    it 'should execute the endpoint and return the response triplet' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action do
            response.add_header 'x-demo', 'hello'
          end
        end
      end
      api = Apia::API.create('MyAPI') do
        routes do
          get 'test', controller: controller, endpoint: :test
        end
      end
      rack = described_class.new(app, api, 'api/v1')
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(result).to be_a Array
      expect(result[1]['x-demo']).to eq 'hello'
    end

    it 'should notify on all requests' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action do
            response.add_header 'x-demo', 'hello'
          end
        end
      end
      api = Apia::API.create('MyAPI') do
        routes do
          get 'test', controller: controller, endpoint: :test
        end
      end
      allow(Apia::Notifications).to receive(:notify)

      rack = described_class.new(app, api, 'api/v1')
      rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(Apia::Notifications).to have_received(:notify).with(:request_start, hash_including(path: 'test', method: 'GET', env: kind_of(Hash))).once
      expect(Apia::Notifications).to have_received(:notify).with(:request, hash_including(path: 'test', request: kind_of(Apia::Request), response: kind_of(Apia::Response))).once
      expect(Apia::Notifications).to have_received(:notify).with(:request_end, hash_including(path: 'test', method: 'GET', env: kind_of(Hash))).once
    end

    it 'should handle OPTIONS requests' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action do
            response.add_field :hello, 'world'
          end
        end
      end
      auth = Apia::Authenticator.create('Authenticator') do
        action do
          cors.methods = %w[GET OPTIONS]
          cors.headers = %w[Authorization Content-Type]
          cors.origin = 'example.com'
          next if request.options?

          response.add_header 'x-executed', 123
        end
      end
      api = Apia::API.create('MyAPI') do
        authenticator auth

        routes do
          get 'test', controller: controller, endpoint: :test
        end
      end
      rack = described_class.new(app, api, 'api/v1')
      mock_request = Rack::MockRequest.env_for(
        '/api/v1/test',
        'REQUEST_METHOD' => 'OPTIONS',
        'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET'
      )
      result = rack.call(mock_request)
      expect(result).to be_a Array
      expect(result[0]).to eq 200

      headers = result[1]
      expect(headers['Access-Control-Allow-Methods']).to eq 'GET, OPTIONS'
      expect(headers['Access-Control-Allow-Headers']).to eq 'Authorization, Content-Type'
      expect(headers['Access-Control-Allow-Origin']).to eq 'example.com'
      expect(headers['x-executed'].nil?).to be true

      # assert body is empty (does not contain the response from the test endpoint)
      expect(result[2][0]).to eq('""')
    end

    it 'should catch rack errors and return an error triplet' do
      api = Apia::API.create('MyAPI')
      rack = described_class.new(app, api, 'api/v1', development: true)
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(result).to be_a Array
      expect(result[0]).to eq 404
      expect(result[2][0]).to include 'route_not_found'
    end

    it 'should catch other errors and return a detailed error triplet in development only' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action { 1 / 0 }
        end
      end
      api = Apia::API.create('MyAPI') do
        routes { get('test', controller: controller, endpoint: :test) }
      end
      rack = described_class.new(app, api, 'api/v1', development: true)
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(result).to be_a Array
      expect(result[0]).to eq 500
      expect(result[2][0]).to include '{"class":"ZeroDivisionError"'
    end

    it 'should notify on errors' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action { 1 / 0 }
        end
      end
      api = Apia::API.create('MyAPI') do
        routes { get('test', controller: controller, endpoint: :test) }
      end
      allow(Apia::Notifications).to receive(:notify)
      rack = described_class.new(app, api, 'api/v1', development: true)
      rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(Apia::Notifications).to have_received(:notify).with(:request_start, hash_including(path: 'test', method: 'GET', env: kind_of(Hash))).once
      expect(Apia::Notifications).to have_received(:notify).with(:request_error, hash_including(path: 'test', exception: kind_of(StandardError))).once
      expect(Apia::Notifications).to have_received(:notify).with(:request_end, hash_including(path: 'test', method: 'GET', env: kind_of(Hash))).once
    end

    it 'should catch other errors and return a basic error triplet in non-development mode' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action { 1 / 0 }
        end
      end
      api = Apia::API.create('MyAPI') do
        routes { get('test', controller: controller, endpoint: :test) }
      end
      rack = described_class.new(app, api, 'api/v1')
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(result).to be_a Array
      expect(result[0]).to eq 500
      expect(result[2][0]).to_not include '{"class":"ZeroDivisionError"'
    end

    it 'should call exception handlers on the API if there are any exceptions' do
      handler_artifacts = {}
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action { 1 / 0 }
        end
      end
      api = Apia::API.create('MyAPI') do
        exception_handler do |exception, options|
          handler_artifacts[:exception] = exception
          handler_artifacts[:options] = options
        end
        routes { get('test', controller: controller, endpoint: :test) }
      end
      rack = described_class.new(app, api, 'api/v1')
      rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(handler_artifacts[:exception]).to be_a ZeroDivisionError
      expect(handler_artifacts[:options][:request]).to be_a Apia::Request
      expect(handler_artifacts[:options][:env]).to be_a Hash
      expect(handler_artifacts[:options][:api]).to eq api
    end

    it 'should validate the whole API in development' do
      api = Apia::API.create('MyAPI') do
        authenticator {}
      end
      rack = described_class.new(app, api, 'api/v1', development: true)
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test/test'))
      expect(result).to be_a Array
      expect(result[0]).to eq 500
      expect(result[2][0]).to include '{"code":"manifest_error"'
    end

    it 'should not validate the whole API when not in development' do
      controller = Apia::Controller.create('Controller') do
        endpoint :test do
          action { response.add_header 'x-demo', 'test' }
        end
      end
      api = Apia::API.create('MyAPI') do
        authenticator {}
        routes { get('test', controller: controller, endpoint: :test) }
      end
      rack = described_class.new(app, api, 'api/v1')
      result = rack.call(Rack::MockRequest.env_for('/api/v1/test'))
      expect(result).to be_a Array
      expect(result[0]).to eq 200
      expect(result[1]['x-demo']).to eq 'test'
    end
  end

  context '.json_triplet' do
    it 'should return json encoded data' do
      data = { hello: 'world' }
      triplet = Apia::Rack.json_triplet(data)
      expect(triplet).to be_a Array
      expect(triplet[0]).to eq 200
      expect(triplet[1]).to be_a Hash
      expect(triplet[2]).to be_a Array
      expect(triplet[2][0]).to eq '{"hello":"world"}'
    end

    it 'should set the content type' do
      data = { hello: 'world' }
      triplet = Apia::Rack.json_triplet(data)
      expect(triplet).to be_a Array
      expect(triplet[1]['content-type']).to eq 'application/json'
    end

    it 'should set the content length' do
      data = { hello: 'world' }
      triplet = Apia::Rack.json_triplet(data)
      expect(triplet).to be_a Array
      expect(triplet[1]['content-length']).to eq '17'
    end

    it 'should set the status' do
      data = { hello: 'world' }
      triplet = Apia::Rack.json_triplet(data, status: 400)
      expect(triplet).to be_a Array
      expect(triplet[0]).to eq 400
    end

    it 'should merge additional headers' do
      data = { hello: 'world' }
      triplet = Apia::Rack.json_triplet(data, headers: { 'x-something' => 'hello' })
      expect(triplet).to be_a Array
      expect(triplet[1]).to be_a Hash
      expect(triplet[1]['x-something']).to eq 'hello'
      expect(triplet[1]['content-length']).to eq '17'
      expect(triplet[1]['content-type']).to eq 'application/json'
    end
  end

  context '.plain_triplet' do
    it 'should return json encoded data' do
      data = 'hello world'
      triplet = Apia::Rack.plain_triplet(data)
      expect(triplet).to be_a Array
      expect(triplet[0]).to eq 200
      expect(triplet[1]).to be_a Hash
      expect(triplet[2]).to be_a Array
      expect(triplet[2][0]).to eq 'hello world'
    end

    it 'should set the content type' do
      data = 'hello world'
      triplet = Apia::Rack.plain_triplet(data)
      expect(triplet).to be_a Array
      expect(triplet[1]['content-type']).to eq 'text/plain'
    end

    it 'should set the content length' do
      data = 'hello world'
      triplet = Apia::Rack.plain_triplet(data)
      expect(triplet).to be_a Array
      expect(triplet[1]['content-length']).to eq '11'
    end

    it 'should set the status' do
      data = 'hello world'
      triplet = Apia::Rack.plain_triplet(data, status: 400)
      expect(triplet).to be_a Array
      expect(triplet[0]).to eq 400
    end

    it 'should merge additional headers' do
      data = 'hello world'
      triplet = Apia::Rack.plain_triplet(data, headers: { 'x-something' => 'hello' })
      expect(triplet).to be_a Array
      expect(triplet[1]).to be_a Hash
      expect(triplet[1]['x-something']).to eq 'hello'
      expect(triplet[1]['content-length']).to eq '11'
      expect(triplet[1]['content-type']).to eq 'text/plain'
    end
  end

  context '.error_triplet' do
    it 'should format the JSON appropriately' do
      triplet = Apia::Rack.error_triplet('example_error', description: 'Some example', detail: { hello: 'world' })
      expect(triplet).to be_a Array
      expect(triplet[0]).to eq 500
      expect(triplet[1]).to be_a Hash
      expect(triplet[2]).to be_a Array
      expect(triplet[2][0]).to eq '{"error":{"code":"example_error","description":"Some example","detail":{"hello":"world"}}}'
    end

    it 'should add the x-api-schema header' do
      triplet = Apia::Rack.error_triplet('example_error', description: 'Some example', detail: { hello: 'world' })
      expect(triplet).to be_a Array
      expect(triplet[1]['x-api-schema']).to eq 'json-error'
    end

    it 'should allow the status to be set' do
      triplet = Apia::Rack.error_triplet('example_error', status: 401)
      expect(triplet).to be_a Array
      expect(triplet[0]).to eq 401
    end

    it 'should allow the headers to be merged' do
      triplet = Apia::Rack.error_triplet('example_error', headers: { 'x-something' => 'testing' })
      expect(triplet).to be_a Array
      expect(triplet[1]['x-something']).to eq 'testing'
      expect(triplet[1]['x-api-schema']).to eq 'json-error'
      expect(triplet[1]['content-type']).to eq 'application/json'
    end
  end
end
