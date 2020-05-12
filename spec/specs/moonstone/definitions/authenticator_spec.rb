# frozen_string_literal: true

require 'spec_helper'
require 'moonstone/definitions/authenticator'

describe Moonstone::Definitions::Authenticator do
  context '#validate' do
    it 'should not add any errors if everything is OK' do
      auth = described_class.new('MyAuthenticator')
      auth.type = :bearer
      auth.action = proc {}
      auth.potential_errors << Moonstone::Error.create('MyError')
      errors = Moonstone::ManifestErrors.new
      auth.validate(errors)
      expect(errors.for(auth)).to be_empty
    end

    it 'should add an error if the type is missing' do
      auth = described_class.new('MyAuthenticator')
      errors = Moonstone::ManifestErrors.new
      auth.validate(errors)
      expect(errors.for(auth)).to include 'MissingType'
    end

    it 'should add an error if the type is not valid' do
      auth = described_class.new('MyAuthenticator')
      auth.type = :invalid
      errors = Moonstone::ManifestErrors.new
      auth.validate(errors)
      expect(errors.for(auth)).to include 'InvalidType'
    end

    it 'should add an error if the action is missing' do
      auth = described_class.new('MyAuthenticator')
      errors = Moonstone::ManifestErrors.new
      auth.validate(errors)
      expect(errors.for(auth)).to include 'MissingAction'
    end

    it 'should add an error if the action is not a proc' do
      auth = described_class.new('MyAuthenticator')
      auth.action = 'potato'
      errors = Moonstone::ManifestErrors.new
      auth.validate(errors)
      expect(errors.for(auth)).to include 'InvalidAction'
    end

    it 'should add an error if any of the potential errors are not errors' do
      auth = described_class.new('MyAuthenticator')
      auth.potential_errors << Moonstone::Controller.create('MyController')
      errors = Moonstone::ManifestErrors.new
      auth.validate(errors)
      expect(errors.for(auth)).to include 'InvalidPotentialError'
    end
  end
end