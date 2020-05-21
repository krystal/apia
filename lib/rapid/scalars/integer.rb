# frozen_string_literal: true

require 'rapid/scalars'
require 'rapid/scalar'

module Rapid
  module Scalars
    class Integer < Rapid::Scalar

      Scalars.register :integer, self

      cast do |value|
        value.to_i
      end

      validator do |value|
        value.is_a?(::Integer)
      end

    end
  end
end