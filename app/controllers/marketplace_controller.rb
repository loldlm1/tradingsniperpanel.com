class MarketplaceController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_marketplace_entry, only: [:show, :checkout]
  before_action :ensure_payment_processor, only: [:checkout]
  before_action :block_privileged_checkout!, only: [:checkout]

  def index
    @marketplace = Marketplace::IndexPresenter.new(
      user: current_user,
      params: params,
      locale: I18n.locale
    ).call
  end

  def show
    @marketplace = Marketplace::ShowPresenter.new(
      user: current_user,
      entry: @entry,
      locale: I18n.locale
    ).call
  end

  def checkout
    return unless ensure_refund_acknowledgement!(fallback: dashboard_marketplace_product_path(@entry.product, locale: I18n.locale))

    result = Marketplace::CheckoutBuilder.new(
      user: current_user,
      entry: @entry,
      base_plan_key: params[:base_plan_key],
      addon_keys: params[:addon_keys],
      locale: I18n.locale
    ).call

    unless result.allowed?
      redirect_to dashboard_marketplace_product_path(@entry.product, locale: I18n.locale),
                  alert: t(result.error_key, **(result.error_options || {})) and return
    end

    return_url = dashboard_marketplace_product_url(@entry.product, locale: I18n.locale)
    checkout_params = {
      mode: "payment",
      line_items: result.line_items,
      success_url: return_url,
      cancel_url: return_url,
      allow_promotion_codes: true,
      client_reference_id: current_user.id,
      payment_intent_data: {
        metadata: result.metadata
      }
    }

    checkout_params = Billing::ApplyReferralDiscount.new(
      user: current_user,
      checkout_params: checkout_params
    ).call

    session = current_user.payment_processor.checkout(**checkout_params)
    redirect_to session.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("[Marketplace] checkout failed user_id=#{current_user&.id} product_id=#{@entry&.product&.id}: #{e.class} - #{e.message}")
    redirect_to dashboard_marketplace_product_path(@entry.product, locale: I18n.locale),
                alert: t("dashboard.marketplace.errors.checkout_error")
  end

  private

  def set_marketplace_entry
    @entry = Marketplace::Catalog.new(user: current_user, include_eligibility: true).entry_for!(slug: params[:id])
  end

  def ensure_payment_processor
    current_user.set_payment_processor(:stripe) unless current_user.payment_processor
  end

  def block_privileged_checkout!
    return unless Access::PrivilegedRolePolicy.full_access?(current_user)

    redirect_to dashboard_marketplace_product_path(@entry.product, locale: I18n.locale),
                alert: t("dashboard.marketplace.errors.privileged_checkout_blocked")
  end
end
