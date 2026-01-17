module Admin
  module Users
    class RoleGuard
      ADMIN_ROLES = %w[admin master_admin].freeze

      def initialize(actor:)
        @actor = actor
      end

      def visible_scope(scope)
        return scope if master_admin?

        scope.where.not(role: User.roles[:master_admin])
      end

      def visible_roles
        return User.roles.keys if master_admin?

        User.roles.keys - ["master_admin"]
      end

      def assignable_roles_for(record:)
        return User.roles.keys if master_admin?
        return [] if record&.admin? || record&.master_admin?

        User.roles.keys - ADMIN_ROLES
      end

      def allow_role_change?(record:, new_role:)
        return true if new_role.blank?
        return true if master_admin?
        return false if record&.admin? || record&.master_admin?

        assignable_roles_for(record: record).include?(new_role.to_s)
      end

      def can_access_record?(record)
        return true if master_admin?

        !record&.master_admin?
      end

      private

      attr_reader :actor

      def master_admin?
        actor&.master_admin?
      end
    end
  end
end
