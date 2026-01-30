module Admin
  module Users
    class RoleGuard
      def initialize(actor:)
        @actor = actor
      end

      def visible_scope(scope)
        scope
      end

      def visible_roles
        User.roles.keys
      end

      def assignable_roles_for(record:)
        return User.roles.keys if master_admin?

        []
      end

      def allow_role_change?(record:, new_role:)
        return true if new_role.blank?
        return true if master_admin?

        return false if record.nil?

        new_role.to_s == record.role
      end

      def can_access_record?(record)
        true
      end

      private

      attr_reader :actor

      def master_admin?
        normalized_actor&.master_admin?
      end

      def normalized_actor
        return actor if actor.is_a?(User) || actor.nil?
        return User.find_by(id: actor["id"] || actor[:id]) if actor.is_a?(Hash)

        actor
      end
    end
  end
end
