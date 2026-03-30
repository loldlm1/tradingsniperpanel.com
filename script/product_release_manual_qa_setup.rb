# frozen_string_literal: true

require "stringio"
require "securerandom"

module ProductReleaseManualQaSetup
  module_function

  QA_PASSWORD = "Password123!"
  QA_USER_EMAIL = "qa.product.release@example.com"
  QA_ADMIN_EMAIL = "qa.admin@example.com"
  QA_USER_NAME = "QA Product Release User"
  QA_ADMIN_NAME = "QA Admin"
  QA_USER_LOCALE = "en"
  QA_TIER = "pro"
  QA_LICENSE_PRIMARY_KEY = "qa-product-release-primary-key"
  QA_LICENSE_SECRET_KEY = "qa-product-release-secret-key"

  def run!
    ensure_license_key_env!
    tag = Time.current.utc.strftime("%Y%m%d%H%M%S")

    admin = ensure_admin!
    user = ensure_qa_user!
    subscription = ensure_manual_subscription!(user:, recorded_by: admin)
    Licenses::ManualSubscriptionSync.new(manual_subscription_id: subscription.id).call

    baseline_current_catalog!

    ea_targets = update_expert_advisors!(tag:)
    addon_product = create_addon_product!(tag:)
    course = create_course!(tag:)
    expected_changes = detect_changes

    verify_expected_changes!(expected_changes:, ea_targets:, addon_product:, course:)

    puts "QA_MANUAL_RELEASE_READY"
    puts "qa_user_email=#{user.email}"
    puts "qa_user_password=#{QA_PASSWORD}"
    puts "qa_admin_email=#{admin.email}"
    puts "qa_admin_password=#{QA_PASSWORD}"
    puts "expected_release_items=#{expected_changes.size}"
    expected_changes.each do |item|
      puts "expected_item=#{item[:product_kind]}:#{item[:action_type]}:#{item[:title_en]}"
    end
  end

  def ensure_admin!
    user = User.find_or_initialize_by(email: QA_ADMIN_EMAIL)
    user.name = QA_ADMIN_NAME
    user.role = :admin
    user.preferred_locale = QA_USER_LOCALE
    user.terms_accepted_at ||= Time.current
    user.password = QA_PASSWORD
    user.password_confirmation = QA_PASSWORD
    user.save!
    user
  end

  def ensure_license_key_env!
    ENV["EA_LICENSE_PRIMARY_KEY"] ||= QA_LICENSE_PRIMARY_KEY
    ENV["EA_LICENSE_SECRET_KEY"] ||= QA_LICENSE_SECRET_KEY
  end

  def ensure_qa_user!
    user = User.find_or_initialize_by(email: QA_USER_EMAIL)
    user.name = QA_USER_NAME
    user.role = :trader
    user.preferred_locale = QA_USER_LOCALE
    user.terms_accepted_at ||= Time.current
    user.password = QA_PASSWORD
    user.password_confirmation = QA_PASSWORD
    user.save!
    user
  end

  def ensure_manual_subscription!(user:, recorded_by:)
    plan = BillingPlan.subscription.active.find_by!(key: "#{QA_TIER}_monthly")
    subscription = ManualSubscription.where(user:, billing_plan: plan).order(ends_at: :desc).first_or_initialize
    now = Time.current
    subscription.assign_attributes(
      amount_cents: plan.amount_cents,
      currency: plan.currency,
      paid_at: now - 1.day,
      starts_at: now - 1.day,
      ends_at: now + 30.days,
      recorded_by_admin: recorded_by,
      status: ManualSubscription::STATUSES[:active]
    )
    subscription.save!
    subscription
  end

  def baseline_current_catalog!
    now = Time.current
    tracked_subjects = ProductReleases::CatalogSnapshotBuilder.new.call

    ProductReleaseSnapshot.transaction do
      tracked_subjects.each do |tracked_subject|
        snapshot = ProductReleaseSnapshot.find_or_initialize_by(
          subject_type: tracked_subject.subject_type,
          subject_id: tracked_subject.subject_id,
          product_kind: tracked_subject.product_kind
        )
        snapshot.signature = tracked_subject.signature
        snapshot.tracked_at = now
        snapshot.save!
      end
    end
  end

  def update_expert_advisors!(tag:)
    eas = ExpertAdvisor.active.where(id: [1, 2]).order(:id)
    raise "Expected two pro EAs for manual QA updates." unless eas.size == 2

    eas.each do |ea|
      filename = ea.bundle_filename.presence || "#{ea.ea_id}.rar"
      ea.ea_files.attach(
        io: StringIO.new("manual-qa-release #{tag} #{ea.ea_id}\n"),
        filename:,
        content_type: "application/octet-stream"
      )
      ea.ensure_bundle_filename!
    end

    eas
  end

  def create_addon_product!(tag:)
    addonable = ExpertAdvisor.find(1)
    plan = BillingPlan.create!(
      key: "qa_release_addon_#{tag}",
      name: "QA Release Add-on #{tag}",
      kind: :one_time,
      amount_cents: 4900,
      currency: "USD",
      active: true,
      sort_order: BillingPlan.maximum(:sort_order).to_i + 1,
      stripe_product_id: "seed_prod_qa_release_addon_#{tag}",
      stripe_price_id: "seed_price_qa_release_addon_#{tag}"
    )

    Addon.create!(
      key: "qa_release_addon_#{tag}",
      addonable:,
      billing_plan: plan
    )

    MarketplaceProduct.create!(
      billing_plan: plan,
      slug: "qa_release_addon_#{tag}",
      key: "marketplace_qa_release_addon_#{tag}",
      status: :active,
      title_en: "QA Release Add-on #{tag}",
      title_es: "Add-on QA Release #{tag}",
      summary_en: "QA-only add-on for grouped release verification.",
      summary_es: "Add-on solo QA para verificar lanzamientos agrupados.",
      description_en: "Created to verify grouped product release notifications with multiple items.",
      description_es: "Creado para verificar notificaciones de lanzamientos agrupados con varios elementos.",
      sort_order: MarketplaceProduct.maximum(:sort_order).to_i + 1
    )
  end

  def create_course!(tag:)
    course = Course.create!(
      slug: "qa-release-course-#{tag}",
      status: "published",
      category: "qa",
      position: Course.maximum(:position).to_i + 1,
      title_en: "QA Release Course #{tag}",
      title_es: "Curso QA Release #{tag}",
      summary_en: "QA-only course for grouped release verification.",
      summary_es: "Curso solo QA para verificar lanzamientos agrupados.",
      description_en: "Created to verify grouped product release notifications with multiple items.",
      description_es: "Creado para verificar notificaciones de lanzamientos agrupados con varios elementos."
    )

    BillingPlan.subscription.active.where(tier: QA_TIER).find_each do |plan|
      CoursePlanEntitlement.find_or_create_by!(course:, billing_plan: plan)
    end

    course
  end

  def detect_changes
    tracked_subjects = ProductReleases::CatalogSnapshotBuilder.new.call
    snapshot_map = ProductReleaseSnapshot.all.index_by { |snapshot| [snapshot.subject_type, snapshot.subject_id, snapshot.product_kind] }

    tracked_subjects.filter_map.with_index do |tracked_subject, index|
      snapshot = snapshot_map[tracked_subject.snapshot_key]
      action_type =
        case tracked_subject.product_kind
        when "expert_advisor"
          next unless snapshot.present?
          next if snapshot.signature == tracked_subject.signature

          "updated"
        when "addon", "course"
          next if snapshot.present?

          "added"
        else
          next
        end

      tracked_subject.to_h.merge(action_type:, position: index)
    end
  end

  def verify_expected_changes!(expected_changes:, ea_targets:, addon_product:, course:)
    expected_titles = ea_targets.map(&:name) + [addon_product.title_en, course.title_en]
    actual_titles = expected_changes.map { |item| item[:title_en] }

    raise "Expected 4 release items, got #{expected_changes.size}" unless expected_changes.size == 4
    raise "Unexpected release titles: #{actual_titles.inspect}" unless actual_titles.sort == expected_titles.sort

    kinds = expected_changes.map { |item| [item[:product_kind], item[:action_type]] }
    expected_kinds = [["expert_advisor", "updated"], ["expert_advisor", "updated"], ["addon", "added"], ["course", "added"]]
    raise "Unexpected release actions: #{kinds.inspect}" unless kinds.sort == expected_kinds.sort
  end
end

ProductReleaseManualQaSetup.run!
