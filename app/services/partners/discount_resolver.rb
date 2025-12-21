module Partners
  class DiscountResolver
    def initialize(user:)
      @user = user
    end

    def call
      profile = partner_profile
      return [nil, nil] unless profile&.active?

      percent = profile.discount_percent_or_default.to_i
      return [nil, nil] unless percent.positive?

      [profile, percent]
    end

    private

    attr_reader :user

    def partner_profile
      return unless user.is_a?(User)

      referrer = user.referrer
      return unless referrer.respond_to?(:partner_profile)

      referrer.partner_profile
    end
  end
end
