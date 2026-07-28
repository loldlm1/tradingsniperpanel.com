require "securerandom"

class ExpertAdvisor < ApplicationRecord
  acts_as_taggable_on :tags

  enum :ea_type, { ea_robot: 0, ea_tool: 1, indicator: 2, script: 3 }

  has_many :user_expert_advisors, dependent: :destroy
  has_many :licenses, dependent: :destroy
  has_many :license_online_sessions, dependent: :destroy
  has_many :license_instance_magic_numbers, dependent: :destroy
  has_many :broker_account_daily_results, dependent: :nullify
  has_many :billing_plan_entitlements, dependent: :destroy
  has_many :billing_plans, through: :billing_plan_entitlements
  has_many :addons, as: :addonable, dependent: :destroy
  has_many :expert_advisor_bundles, dependent: :destroy
  has_one_attached :ea_files

  default_scope { where(deleted_at: nil) }
  scope :active, -> { where(deleted_at: nil) }
  scope :ordered_by_rank, -> { order(:tier_rank, :name) }

  before_validation :assign_ea_id, on: :create

  validates :ea_id, presence: true, uniqueness: true
  validates :tier_rank, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Prevent accidental EA identifier changes once issued
  validate :ea_id_immutable, on: :update

  def self.ransackable_associations(_auth_object = nil)
    %w[tags]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at ea_id ea_type id name tier_rank trial_enabled updated_at]
  end

  def doc_guide_for(locale)
    key = "doc_guide_#{locale}"
    guide = respond_to?(key) ? public_send(key) : nil
    guide.presence || doc_guide_en
  end

  def to_param
    ea_id
  end

  def allowed_for_tier?(tier)
    allowed = subscription_tiers
    return true if allowed.blank?

    allowed.map(&:to_s).include?(tier.to_s)
  end

  def self.subscription_entitlements_for(plan)
    product = Billing::SubscriptionCatalog.product_for_plan(plan)
    return [] unless product

    records = active
      .joins(:billing_plan_entitlements)
      .where(
        billing_plan_entitlements: { billing_plan_id: plan.id },
        ea_id: product.ea_ids
      )
      .distinct
      .to_a

    return [] unless records.map(&:ea_id).sort == product.ea_ids.sort

    records.sort_by { |expert_advisor| product.ea_ids.index(expert_advisor.ea_id) }
  end

  def daily_results_supported?
    ea_id != Billing::ChuSniperPricing::TIER
  end

  def subscription_tiers
    if billing_plan_entitlements.loaded? || billing_plans.loaded?
      tiers = billing_plans.select(&:subscription?).map(&:tier)
      return tiers.compact.uniq if tiers.present?
    end

    tiers = billing_plans.subscription.distinct.pluck(:tier)
    return tiers.compact.uniq if tiers.present?

    Array(allowed_subscription_tiers).presence
  end

  def bundle_filename
    return unless ea_files.attached?

    "#{ea_id}.#{bundle_extension}"
  end

  def marketplace_product_ids
    MarketplaceProduct.where(billing_plan_id: billing_plans.select(:id)).pluck(:id)
  end

  def ensure_bundle_filename!
    return unless ea_files.attached?

    target = bundle_filename
    return if target.blank?

    blob = ea_files.blob
    return if blob.filename.to_s == target

    blob.update!(filename: target)
  end

  private

  def bundle_extension
    extension = ea_files.blob.filename.extension
    extension = extension.presence || "rar"
    extension
  end

  def assign_ea_id
    return if ea_id.present?

    base = name.to_s.parameterize.presence || "expert-advisor"
    self.ea_id = "#{base}-#{SecureRandom.hex(4)}"
  end

  def ea_id_immutable
    return unless ea_id_changed?

    errors.add(:ea_id, :immutable)
  end
end
