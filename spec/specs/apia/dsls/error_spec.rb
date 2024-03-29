# frozen_string_literal: true

require 'spec_helper'
require 'apia/dsls/error'
require 'apia/definitions/error'

describe Apia::DSLs::Error do
  subject(:error) { Apia::Definitions::Error.new('TestError') }
  subject(:dsl) { Apia::DSLs::Error.new(error) }

  include_examples 'has fields dsl' do
    subject(:definition) { error }
  end

  context '#name' do
    it 'should define the name' do
      dsl.name 'My error'
      expect(error.name).to eq 'My error'
    end
  end

  context '#description' do
    it 'should define the description' do
      dsl.description 'My error'
      expect(error.description).to eq 'My error'
    end
  end

  context '#code' do
    it 'should set the code' do
      dsl.code :my_error
      expect(error.code).to eq :my_error
    end
  end

  context '#http_status' do
    it 'should set the HTTP status' do
      dsl.http_status 403
      expect(error.http_status).to eq 403
    end
  end

  context '#catch_exception' do
    it 'should store the exception to catch' do
      dsl.catch_exception StandardError do |fields|
        fields[:test] = 'hello'
      end
      expect(error.catchable_exceptions[StandardError]).to be_a Proc
      fields = {}
      error.catchable_exceptions[StandardError].call(fields)
      expect(fields[:test]).to eq 'hello'
    end
  end
end
