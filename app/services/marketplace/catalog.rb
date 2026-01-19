module Marketplace
  class Catalog
    Entry = Struct.new(
      :product,
      :plan,
      :purchased,
      :purchase,
      :price_display,
      :expert_advisors,
      :courses,
      :marketplace_assets,
      :owned_expert_advisors,
      :owned_courses,
      :owned_assets,
      :remaining_expert_advisors,
      :remaining_courses,
      :remaining_assets,
      :addon,
      :addonable,
      :eligible,
      :eligibility_reason,
      :tags,
      keyword_init: true
    ) do
      def addon?
        addon.present?
      end
    end

    def initialize(user:, scope: MarketplaceProduct, include_eligibility: false)
      @user = user
      @scope = scope
      @include_eligibility = include_eligibility
    end

    def call
      purchase_map, purchased_ea_ids, purchased_course_ids, purchased_asset_ids = purchase_context

      product_scope.map do |product|
        build_entry(product, purchase_map, purchased_ea_ids, purchased_course_ids, purchased_asset_ids)
      end
    end

    def entry_for!(slug:)
      purchase_map, purchased_ea_ids, purchased_course_ids, purchased_asset_ids = purchase_context
      product = product_scope.find_by!(slug: slug)

      build_entry(product, purchase_map, purchased_ea_ids, purchased_course_ids, purchased_asset_ids)
    end

    private

    attr_reader :user, :scope, :include_eligibility

    def product_scope
      scope.active
           .joins(:billing_plan)
           .merge(BillingPlan.active)
           .ordered
           .includes(
             image_attachment: :blob,
             billing_plan: [
               { expert_advisors: :tags },
               { courses: :tags },
               { marketplace_assets: :tags },
               { addon: { addonable: :tags } }
             ]
           )
    end

    def purchase_context
      purchases = purchases_for_user
      purchase_map = purchases.index_by(&:billing_plan_id)
      [
        purchase_map,
        purchased_ea_ids(purchases),
        purchased_course_ids(purchases),
        purchased_asset_ids(purchases)
      ]
    end

    def purchases_for_user
      return MarketplacePurchase.none unless user

      MarketplacePurchase.where(user: user).includes(billing_plan: [:expert_advisors, :courses, :marketplace_assets])
    end

    def purchased_ea_ids(purchases)
      purchases.flat_map { |purchase| purchase.billing_plan.expert_advisors.map(&:id) }.uniq
    end

    def purchased_course_ids(purchases)
      purchases.flat_map { |purchase| purchase.billing_plan.courses.map(&:id) }.uniq
    end

    def purchased_asset_ids(purchases)
      purchases.flat_map { |purchase| purchase.billing_plan.marketplace_assets.map(&:id) }.uniq
    end

    def build_entry(product, purchase_map, purchased_ea_ids, purchased_course_ids, purchased_asset_ids)
      plan = product.billing_plan
      expert_advisors = sorted_expert_advisors(product.expert_advisors)
      courses = sorted_courses(product.courses)
      assets = sorted_assets(product.marketplace_assets)
      owned_expert_advisors = expert_advisors.select { |ea| purchased_ea_ids.include?(ea.id) }
      owned_courses = courses.select { |course| purchased_course_ids.include?(course.id) }
      owned_assets = assets.select { |asset| purchased_asset_ids.include?(asset.id) }
      addon = plan&.addon
      addonable = addon&.addonable
      eligibility = addon && include_eligibility ? Addons::Eligibility.new(user: user, addon: addon).call : nil
      tags = combined_tags(expert_advisors, courses, assets, addonable)

      Entry.new(
        product: product,
        plan: plan,
        purchased: purchase_map.key?(plan&.id),
        purchase: purchase_map[plan&.id],
        price_display: price_display(plan),
        expert_advisors: expert_advisors,
        courses: courses,
        marketplace_assets: assets,
        owned_expert_advisors: owned_expert_advisors,
        owned_courses: owned_courses,
        owned_assets: owned_assets,
        remaining_expert_advisors: expert_advisors - owned_expert_advisors,
        remaining_courses: courses - owned_courses,
        remaining_assets: assets - owned_assets,
        addon: addon,
        addonable: addonable,
        eligible: eligibility&.allowed?,
        eligibility_reason: eligibility&.reason,
        tags: tags
      )
    end

    def sorted_expert_advisors(expert_advisors)
      expert_advisors.sort_by { |ea| [ea.tier_rank.to_i, ea.name.to_s] }
    end

    def sorted_courses(courses)
      courses.sort_by { |course| [course.position.to_i, course.title_en.to_s] }
    end

    def sorted_assets(assets)
      assets.sort_by { |asset| [asset.sort_order.to_i, asset.title_en.to_s] }
    end

    def combined_tags(*collections)
      collections.flatten.compact.flat_map { |item| item.tag_list.to_a }.uniq.sort_by { |tag| tag.downcase }
    end

    def price_display(plan)
      return nil unless plan&.amount_cents

      ActionController::Base.helpers.number_to_currency(plan.amount_cents / 100.0, unit: "$", precision: 2)
    end
  end
end
