# frozen_string_literal: true

require "securerandom"

module ProductReleaseMultiReleaseQaSetup
  module_function

  PASSWORD = "Password123!"
  USER_EMAIL = "qa.product.release.scroll@example.com"
  ADMIN_EMAIL = "qa.admin@example.com"
  NEWER_COUNT = 24
  OLDER_COUNT = 3

  def run!
    admin = ensure_admin!
    user = ensure_user!
    dismiss_existing_releases_for!(user)

    addonable = ExpertAdvisor.active.first || ExpertAdvisor.create!(
      name: "QA Release Base EA",
      ea_type: :ea_tool,
      tier_rank: ExpertAdvisor.maximum(:tier_rank).to_i + 1
    )

    older_release = create_release!(
      admin:,
      published_at: 2.days.ago,
      prefix: "QA Older Add-on",
      count: OLDER_COUNT,
      addonable:
    )
    newer_release = create_release!(
      admin:,
      published_at: 1.day.ago,
      prefix: "QA Newer Add-on",
      count: NEWER_COUNT,
      addonable:
    )

    puts "QA_MULTI_RELEASE_READY"
    puts "qa_email=#{user.email}"
    puts "qa_password=#{PASSWORD}"
    puts "older_release_id=#{older_release.id}"
    puts "newer_release_id=#{newer_release.id}"
    puts "older_count=#{OLDER_COUNT}"
    puts "newer_count=#{NEWER_COUNT}"
  end

  def ensure_admin!
    user = User.find_or_initialize_by(email: ADMIN_EMAIL)
    user.name = "QA Admin"
    user.role = :admin
    user.preferred_locale = "en"
    user.terms_accepted_at ||= Time.current
    user.password = PASSWORD
    user.password_confirmation = PASSWORD
    user.save!
    user
  end

  def ensure_user!
    user = User.find_or_initialize_by(email: USER_EMAIL)
    user.name = "QA Product Release Scroll User"
    user.role = :trader
    user.preferred_locale = "en"
    user.terms_accepted_at ||= Time.current
    user.password = PASSWORD
    user.password_confirmation = PASSWORD
    user.save!
    user
  end

  def dismiss_existing_releases_for!(user)
    ProductRelease.find_each do |release|
      user.product_release_dismissals.find_or_create_by!(product_release: release) do |dismissal|
        dismissal.dismissed_at = Time.current
      end
    end
  end

  def create_release!(admin:, published_at:, prefix:, count:, addonable:)
    release = ProductRelease.create!(published_by: admin, published_at: published_at)

    count.times do |index|
      title = format("%s %02d", prefix, index + 1)
      product = create_addon_product!(
        title: title,
        key_prefix: prefix.parameterize(separator: "_"),
        index: index + 1,
        addonable: addonable
      )
      release.product_release_items.create!(
        subject: product,
        product_kind: :addon,
        action_type: :added,
        title_en: product.title_en,
        title_es: product.title_es,
        position: index
      )
    end

    release
  end

  def create_addon_product!(title:, key_prefix:, index:, addonable:)
    normalized_prefix = key_prefix.to_s.gsub(/[^a-z0-9_]/, "").slice(0, 12)
    key = "#{normalized_prefix}_#{index}_#{SecureRandom.hex(2)}"
    sort_order = MarketplaceProduct.maximum(:sort_order).to_i + 1

    plan = BillingPlan.create!(
      key: key,
      name: "#{title} Plan",
      kind: :one_time,
      amount_cents: 4900,
      currency: "USD",
      active: true,
      sort_order: BillingPlan.maximum(:sort_order).to_i + 1,
      stripe_product_id: "seed_prod_#{key}",
      stripe_price_id: "seed_price_#{key}"
    )

    Addon.create!(
      key: key,
      addonable: addonable,
      billing_plan: plan
    )

    MarketplaceProduct.create!(
      billing_plan: plan,
      slug: key,
      status: :active,
      title_en: title,
      title_es: title,
      summary_en: "QA add-on for multi-release notification checks.",
      summary_es: "Add-on QA para validar notificaciones con muchos releases.",
      description_en: "Created to verify ordering and clear-all behavior in the dashboard notification dropdown.",
      description_es: "Creado para verificar el orden y el borrado global en el dropdown de notificaciones del dashboard.",
      sort_order: sort_order
    )
  end
end

ProductReleaseMultiReleaseQaSetup.run!
