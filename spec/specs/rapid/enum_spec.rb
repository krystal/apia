# frozen_string_literal: true

require 'spec_helper'
require 'rapid/enum'

describe Rapid::Enum do
  context '#cast' do
    it 'should return the casted value' do
      enum = Rapid::Enum.create('ExampleEnum') do
        value 'active'
      end
      expect(enum.cast('active')).to eq 'active'
    end

    it 'should use the cast block if one exists' do
      enum = Rapid::Enum.create('ExampleEnum') do
        value 'ACTIVE'
        cast(&:upcase)
      end
      expect(enum.cast('active')).to eq 'ACTIVE'
    end

    it 'should raise an error if the resulting casted value is not valid' do
      enum = Rapid::Enum.create('ExampleEnum') do
        value 'active'
        value 'inactive'
      end
      expect { enum.cast('suspended') }.to raise_error(Rapid::InvalidEnumOptionError)
    end
  end
end