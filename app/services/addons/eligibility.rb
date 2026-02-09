module Addons
  class Eligibility
    Result = Struct.new(:allowed, :reason, :addon, :addonable, keyword_init: true) do
      def allowed?
        !!allowed
      end
    end

    def initialize(user:, addon:)
      @user = user
      @addon = addon
    end

    def call
      return Result.new(allowed: false, reason: :missing_user, addon: addon, addonable: addonable) unless user
      return Result.new(allowed: false, reason: :missing_addon, addon: addon, addonable: addonable) unless addon
      return Result.new(allowed: true, addon: addon, addonable: addonable) if Access::PrivilegedRolePolicy.full_access?(user)

      case addonable
      when ExpertAdvisor
        eligibility_for_expert_advisor(addonable)
      when Course
        eligibility_for_course(addonable)
      when MarketplaceAsset
        eligibility_for_marketplace_asset(addonable)
      else
        Result.new(allowed: false, reason: :invalid_addonable, addon: addon, addonable: addonable)
      end
    end

    private

    attr_reader :user, :addon

    def addonable
      addon&.addonable
    end

    def eligibility_for_expert_advisor(expert_advisor)
      license = License.find_by(user: user, expert_advisor: expert_advisor)
      return Result.new(allowed: false, reason: :missing_base, addon: addon, addonable: expert_advisor) unless license
      return Result.new(allowed: false, reason: :base_trial, addon: addon, addonable: expert_advisor) if license.trial?
      return Result.new(allowed: false, reason: :base_inactive, addon: addon, addonable: expert_advisor) if license.expired_by_time?
      return Result.new(allowed: true, addon: addon, addonable: expert_advisor) if license.access_source_one_time?

      subscription_status = Billing::SubscriptionStatus.new(active_subscription)
      return Result.new(allowed: false, reason: :base_trial, addon: addon, addonable: expert_advisor) if subscription_status.trialing?
      return Result.new(allowed: false, reason: :base_inactive, addon: addon, addonable: expert_advisor) unless subscription_status.paid_active?

      Result.new(allowed: true, addon: addon, addonable: expert_advisor)
    end

    def eligibility_for_course(course)
      enrollment = CourseEnrollment.find_by(user: user, course: course)
      if enrollment&.access_source_one_time?
        return Result.new(allowed: true, addon: addon, addonable: course)
      end

      subscription_status = Billing::SubscriptionStatus.new(active_subscription)
      return Result.new(allowed: false, reason: :base_trial, addon: addon, addonable: course) if subscription_status.trialing?
      return Result.new(allowed: false, reason: :base_inactive, addon: addon, addonable: course) unless subscription_status.paid_active?

      tier = subscription_tier(active_subscription)
      return Result.new(allowed: false, reason: :missing_base, addon: addon, addonable: course) unless course.allowed_for_tier?(tier)

      Result.new(allowed: true, addon: addon, addonable: course)
    end

    def eligibility_for_marketplace_asset(asset)
      access = Marketplace::AssetAccess.new(user: user, asset: asset).call
      return Result.new(allowed: true, addon: addon, addonable: asset) if access.allowed?

      Result.new(allowed: false, reason: :missing_base, addon: addon, addonable: asset)
    end

    def active_subscription
      @active_subscription ||= Billing::ActiveSubscriptionFinder.new(user: user).call.subscription
    end

    def subscription_tier(subscription)
      Billing::SubscriptionPlanResolver.new(subscription: subscription).tier
    end
  end
end
