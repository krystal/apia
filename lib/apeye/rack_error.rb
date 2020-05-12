# frozen_string_literal: true

module APeye
  class RackError < StandardError
    def initialize(http_status, code, message)
      @http_status = http_status
      @code = code
      @message = message
    end

    def triplet
      body = { error: { code: @code, message: @message } }.to_json
      [@http_status, { 'Content-Type' => 'application/json', 'Content-Length' => body.bytesize.to_s }, [body]]
    end
  end
end