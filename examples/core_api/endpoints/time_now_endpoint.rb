# frozen_string_literal: true

require 'core_api/objects/time_zone'

module CoreAPI
  module Endpoints
    class TimeNowEndpoint < Apia::Endpoint

      description 'Returns the current time'
      argument :timezone, type: Objects::TimeZone
      # argument :filters, [:string]
      field :time, type: Objects::Time, include: 'unix,day_of_week'
      scope 'time' # TODO: what does this do?

      def call
        response.add_field :time, get_time_now
      end

      private

      def get_time_now
        Time.now
      end

    end
  end
end
