module Auth
  class GoogleOauth
    Result = Struct.new(:user, :status, keyword_init: true)

    def initialize(auth:, locale:)
      @auth = auth
      @locale = locale
    end

    def call
      user = find_or_initialize_user
      apply_oauth_attributes(user)

      status = status_for(user)
      if user.save
        Result.new(user:, status:)
      else
        Result.new(user:, status: :error)
      end
    end

    private

    attr_reader :auth, :locale

    def find_or_initialize_user
      find_by_provider || find_by_email || build_new_user
    end

    def find_by_provider
      User.find_by(provider:, uid:)
    end

    def find_by_email
      email = auth.info&.email&.downcase
      return if email.blank?

      User.find_by(email: email).tap do |user|
        next unless user

        user.provider ||= provider
        user.uid ||= uid
      end
    end

    def build_new_user
      User.new(
        email: auth.info&.email,
        name: auth.info&.name,
        password: Devise.friendly_token[0, 20],
        provider: provider,
        uid: uid,
        preferred_locale: locale.to_s,
        terms_accepted_at: Time.current
      )
    end

    def apply_oauth_attributes(user)
      user.oauth_data = sanitized_auth_data
      user.provider ||= provider
      user.uid ||= uid
      user.preferred_locale ||= locale.to_s
    end

    def status_for(user)
      return :created if user.new_record?
      return :linked if user.will_save_change_to_provider? || user.will_save_change_to_uid?

      :existing
    end

    def provider
      auth.provider
    end

    def uid
      auth.uid
    end

    def sanitized_auth_data
      info = auth.info.respond_to?(:to_h) ? auth.info.to_h : {}
      credentials = auth.credentials.respond_to?(:to_h) ? auth.credentials.to_h.slice("expires_at") : {}

      {
        provider: provider,
        uid: uid,
        info: info.compact_blank,
        credentials: credentials.compact_blank
      }.compact
    end
  end
end
