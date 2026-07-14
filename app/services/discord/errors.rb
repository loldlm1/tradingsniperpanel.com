module Discord
  module Errors
  end

  class Error < StandardError
    attr_reader :code, :status, :retry_after

    def initialize(message = "Discord request failed", code:, status: nil, retry_after: nil)
      @code = code.to_s
      @status = status
      @retry_after = retry_after
      super(message)
    end
  end

  class ConfigurationError < Error; end
  class UnauthorizedError < Error; end
  class ForbiddenError < Error; end
  class NotFoundError < Error; end
  class RateLimitedError < Error; end
  class ServerError < Error; end
  class TransportError < Error; end
  class InvalidResponseError < Error; end
end
