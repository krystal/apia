# frozen_string_literal: true

require 'spec_helper'
require 'apia/definitions/field'
require 'apia/object'

describe Apia::Definitions::Field do
  context '#array?' do
    it 'should be true if the field can be an array' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :string
      field.array = true
      expect(field.array?).to be true
    end

    it 'should return false if array is not specified' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :string
      expect(field.array?).to be false
    end

    it 'should return false if it is not an array' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :string
      field.array = false
      expect(field.array?).to be false
    end
  end

  context '#null?' do
    it 'should be true if the field can be nil' do
      field = Apia::Definitions::Field.new(:id)
      field.null = true
      expect(field.null?).to be true
    end

    it 'should be false if the field does not specify a preference' do
      field = Apia::Definitions::Field.new(:id)
      expect(field.null?).to be false
    end

    it 'should be false if the field cannot be nil' do
      field = Apia::Definitions::Field.new(:id)
      field.null = false
      expect(field.null?).to be false
    end
  end

  context '#include?' do
    it 'should return true when there is no condition' do
      field = Apia::Definitions::Field.new(:id)
      expect(field.include?(123, nil)).to be true
    end

    it 'should return true if the condition returns true' do
      field = Apia::Definitions::Field.new(:id)
      field.condition = proc { true }
      expect(field.include?(123, nil)).to be true
    end

    it 'should return false if the condition does not return true' do
      field = Apia::Definitions::Field.new(:id)
      field.condition = proc { false }
      expect(field.include?(123, nil)).to be false
    end

    it 'should receive the value' do
      field = Apia::Definitions::Field.new(:id)
      field.condition = proc { |value| value.to_i > 10 }
      expect(field.include?(1, nil)).to be false
      expect(field.include?(11, nil)).to be true
    end

    it 'should receive a request' do
      field = Apia::Definitions::Field.new(:id)
      field.condition = proc { |_, request| request.to_i > 10 }
      expect(field.include?(1, 1)).to be false
      expect(field.include?(1, 11)).to be true
    end
  end

  context '#raw_value_from_object' do
    it 'should be able to pull a value from a hash' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :integer
      expect(field.raw_value_from_object(id: 1234)).to eq 1234
    end

    it 'should be able to pull false values from a hash where the symbols are keys' do
      field = Apia::Definitions::Field.new(:active)
      field.type = :boolean
      expect(field.raw_value_from_object(active: false)).to eq false
    end

    it 'should be able to pull nil values from a hash where both strings & symbols are provided (for consistency)' do
      field = Apia::Definitions::Field.new(:active)
      field.type = :string
      expect(field.raw_value_from_object(active: nil, 'active' => 'hello')).to eq nil
    end

    it 'should be able to pull a value from an object' do
      require 'ostruct'
      field = Apia::Definitions::Field.new(:id)
      field.type = :integer
      struct = Struct.new(:id).new
      struct.id = 1234
      expect(field.raw_value_from_object(struct)).to eq 1234
    end

    it 'should call the backend block if one is given' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :string
      field.backend = proc { |n| "#{n}!" }
      expect(field.raw_value_from_object(444)).to eq '444!'
    end

    it 'should use the name of the backend when looking up from a hash' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :string
      field.backend = :something
      expect(field.raw_value_from_object({ something: 'Hello!' })).to eq 'Hello!'
    end

    it 'should use the name of the backend as a method name when looking up from any non-hash object' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :string
      field.backend = :something
      struct = Struct.new(:something).new('World!')
      expect(field.raw_value_from_object(struct)).to eq 'World!'
    end
  end

  context '#value' do
    it 'should raise an error if the value is not valid' do
      field = Apia::Definitions::Field.new(:id)
      field.type = :integer
      expect do
        field.value({ id: '444' })
      end.to raise_error(Apia::InvalidScalarValueError)
    end

    it 'should return an array if defined as an array' do
      field = Apia::Definitions::Field.new(:names)
      field.type = :string
      field.array = true
      value = field.value({ names: %w[Adam Michael] })
      expect(value).to be_a Array
      expect(value[0]).to eq 'Adam'
      expect(value[1]).to eq 'Michael'
    end

    it 'should return an array if defined as an array with nested types' do
      type = Class.new(Apia::Object) do
        field :name, type: :string
        field :age, type: :integer
      end

      field = Apia::Definitions::Field.new(:users)
      field.type = type
      field.array = true
      value = field.value({ users: [
                            { name: 'Adam', age: 20 },
                            { name: 'Michael', age: 25 }
                          ] })
      expect(value).to be_a Array
      expect(value[0]).to be_a Hash

      expect(value[0][:name]).to eq 'Adam'
      expect(value[0][:age]).to eq 20

      expect(value[1]).to be_a Hash
      expect(value[1][:name]).to eq 'Michael'
      expect(value[1][:age]).to eq 25
    end
  end
end
