require "json"
require "net/http"
require "uri"

module Discord
  class Client
    API_BASE_URL = "https://discord.com/api/v10/".freeze
    Response = Data.define(:status, :headers, :body)
    MemberResult = Data.define(:membership_pending)

    class NetHttpTransport
      def initialize(open_timeout: 5, read_timeout: 10, write_timeout: 10)
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @write_timeout = write_timeout
      end

      def call(method:, uri:, headers:, body: nil)
        request = request_class(method).new(uri)
        headers.each { |key, value| request[key] = value }
        request.body = body if body

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          write_timeout: write_timeout
        ) { |http| http.request(request) }

        Response.new(
          status: response.code.to_i,
          headers: response.each_header.to_h,
          body: response.body.to_s
        )
      rescue Timeout::Error, SocketError, EOFError, IOError, SystemCallError
        raise TransportError.new(code: :transport_error)
      end

      private

      attr_reader :open_timeout, :read_timeout, :write_timeout

      def request_class(method)
        {
          get: Net::HTTP::Get,
          post: Net::HTTP::Post,
          put: Net::HTTP::Put,
          delete: Net::HTTP::Delete
        }.fetch(method)
      end
    end

    def initialize(
      configuration: Discord.configuration,
      transport: NetHttpTransport.new,
      clock: Time,
      logger: Rails.logger
    )
      @configuration = configuration
      @transport = transport
      @clock = clock
      @logger = logger
    end

    def exchange_code(code:)
      response = request(
        method: :post,
        path: "oauth2/token",
        headers: { "Content-Type" => "application/x-www-form-urlencoded" },
        body: URI.encode_www_form(
          client_id: configuration.client_id,
          client_secret: configuration.client_secret,
          grant_type: "authorization_code",
          code: code,
          redirect_uri: configuration.redirect_uri
        ),
        expected_statuses: [ 200 ]
      )
      payload = parse_json(response.body)
      access_token = payload["access_token"].to_s
      raise_invalid_response! if access_token.blank?

      {
        access_token: access_token,
        refresh_token: payload["refresh_token"].to_s.presence,
        token_type: payload["token_type"].to_s.presence,
        expires_in: Integer(payload["expires_in"], exception: false),
        scope: payload["scope"].to_s.presence
      }
    end

    def current_user(access_token:)
      response = request(
        method: :get,
        path: "users/@me",
        headers: bearer_headers(access_token),
        expected_statuses: [ 200 ]
      )
      payload = parse_json(response.body)
      user_id = payload["id"].to_s
      raise_invalid_response! if user_id.blank?

      {
        id: user_id,
        username: payload["username"].to_s.presence,
        global_name: payload["global_name"].to_s.presence
      }
    end

    def add_guild_member(user_id:, access_token:)
      response = request(
        method: :put,
        path: "guilds/#{configuration.guild_id}/members/#{user_id}",
        headers: bot_headers,
        body: JSON.generate(access_token: access_token),
        expected_statuses: [ 201, 204 ]
      )
      pending = response.status == 201 ? parse_json(response.body)["pending"] : nil

      MemberResult.new(membership_pending: pending.in?([ true, false ]) ? pending : nil)
    end

    def add_vip_role(user_id:)
      request(
        method: :put,
        path: role_path(user_id),
        headers: bot_headers,
        expected_statuses: [ 204 ]
      )
      true
    end

    def remove_vip_role(user_id:)
      request(
        method: :delete,
        path: role_path(user_id),
        headers: bot_headers,
        expected_statuses: [ 204 ],
        idempotent_not_found: true
      )
      true
    end

    private

    attr_reader :configuration, :transport, :clock, :logger

    def request(method:, path:, headers:, expected_statuses:, body: nil, idempotent_not_found: false)
      response = transport.call(
        method: method,
        uri: URI.join(API_BASE_URL, path),
        headers: headers,
        body: body
      )
      return response if expected_statuses.include?(response.status)
      return response if idempotent_not_found && response.status == 404

      raise_for_response!(response)
    rescue Error
      raise
    rescue StandardError
      raise TransportError.new(code: :transport_error)
    end

    def raise_for_response!(response)
      status = response.status.to_i
      error = case status
      when 401
        UnauthorizedError.new(code: :unauthorized, status: status)
      when 403
        ForbiddenError.new(code: :forbidden, status: status)
      when 404
        NotFoundError.new(code: :not_found, status: status)
      when 429
        RateLimitedError.new(
          code: :rate_limited,
          status: status,
          retry_after: retry_after(response)
        )
      when 500..599
        ServerError.new(code: :server_error, status: status)
      else
        Error.new(code: :api_error, status: status)
      end
      logger.warn("Discord API request failed code=#{error.code} status=#{status} at=#{clock.now.utc.iso8601}")
      raise error
    end

    def retry_after(response)
      header_value = response.headers.to_h.find { |key, _| key.to_s.downcase == "retry-after" }&.last
      body_value = parse_json(response.body, allow_invalid: true)["retry_after"]
      Float(header_value.presence || body_value, exception: false)
    end

    def parse_json(body, allow_invalid: false)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      return {} if allow_invalid

      raise_invalid_response!
    end

    def raise_invalid_response!
      raise InvalidResponseError.new(code: :invalid_response)
    end

    def bearer_headers(access_token)
      { "Authorization" => "Bearer #{access_token}" }
    end

    def bot_headers
      {
        "Authorization" => "Bot #{configuration.bot_token}",
        "Content-Type" => "application/json"
      }
    end

    def role_path(user_id)
      "guilds/#{configuration.guild_id}/members/#{user_id}/roles/#{configuration.vip_role_id}"
    end
  end
end
