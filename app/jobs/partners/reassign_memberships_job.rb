module Partners
  class ReassignMembershipsJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      user = User.find_by(id: user_id)
      return unless user

      Partners::MembershipManager.new.reassign_descendants_for(user)
    end
  end
end
