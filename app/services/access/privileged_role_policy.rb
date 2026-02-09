module Access
  class PrivilegedRolePolicy
    PRIVILEGED_ROLES = %w[admin master_admin full_trader].freeze

    def self.full_access?(user)
      new(user: user).full_access?
    end

    def initialize(user:)
      @user = user
    end

    def full_access?
      return false unless user.is_a?(User)

      PRIVILEGED_ROLES.include?(user.role.to_s)
    end

    private

    attr_reader :user
  end
end
