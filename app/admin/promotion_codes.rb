ActiveAdmin.register PromotionCode do
  permit_params :code, :percent_off, :active, :title_en, :title_es, :body_en, :body_es,
                :cta_label_en, :cta_label_es, :expires_at, :max_redemptions

  scope :all, default: true
  scope(:active) { |scope| scope.kept.where(active: true) }
  scope(:inactive) { |scope| scope.kept.where(active: false) }
  scope(:archived) { |scope| scope.where.not(archived_at: nil) }

  controller do
    def scoped_collection
      super.order(active: :desc, updated_at: :desc, id: :desc)
    end

    def create
      result = Admin::PromotionCodeUpsert.new(attributes: promotion_params).call

      if result.ok?
        redirect_to admin_promotion_code_path(result.promotion_code), notice: t("active_admin.promotion_codes.created")
      else
        @promotion_code = result.promotion_code
        flash.now[:alert] = result.errors.to_sentence
        render :new, status: :ok
      end
    end

    def update
      result = Admin::PromotionCodeUpsert.new(promotion_code: resource, attributes: promotion_params).call

      if result.ok?
        redirect_to admin_promotion_code_path(result.promotion_code), notice: t("active_admin.promotion_codes.updated")
      else
        @promotion_code = result.promotion_code
        flash.now[:alert] = result.errors.to_sentence
        render :edit, status: :ok
      end
    end

    private

    def promotion_params
      params.require(:promotion_code).permit(
        :code,
        :percent_off,
        :active,
        :title_en,
        :title_es,
        :body_en,
        :body_es,
        :cta_label_en,
        :cta_label_es,
        :expires_at,
        :max_redemptions
      )
    end
  end

  member_action :activate, method: :post do
    result = Admin::PromotionCodeActivation.new(promotion_code: resource, active: true).call

    if result.ok?
      redirect_to admin_promotion_code_path(resource), notice: t("active_admin.promotion_codes.activated")
    else
      redirect_to admin_promotion_code_path(resource), alert: result.errors.to_sentence
    end
  end

  member_action :deactivate, method: :post do
    result = Admin::PromotionCodeActivation.new(promotion_code: resource, active: false).call

    if result.ok?
      redirect_to admin_promotion_code_path(resource), notice: t("active_admin.promotion_codes.deactivated")
    else
      redirect_to admin_promotion_code_path(resource), alert: result.errors.to_sentence
    end
  end

  member_action :archive, method: :post do
    resource.archive!
    Billing::StripePromotionCodeSync.new(promotion_code: resource).call
    redirect_to admin_promotion_code_path(resource), notice: t("active_admin.promotion_codes.archived")
  rescue StandardError => e
    redirect_to admin_promotion_code_path(resource), alert: e.message
  end

  member_action :restore, method: :post do
    resource.restore!
    redirect_to admin_promotion_code_path(resource), notice: t("active_admin.promotion_codes.restored")
  rescue StandardError => e
    redirect_to admin_promotion_code_path(resource), alert: e.message
  end

  action_item :activate, only: :show, if: proc { !resource.active? && !resource.archived? } do
    link_to t("active_admin.promotion_codes.actions.activate"), activate_admin_promotion_code_path(resource), method: :post
  end

  action_item :deactivate, only: :show, if: proc { resource.active? && !resource.archived? } do
    link_to t("active_admin.promotion_codes.actions.deactivate"), deactivate_admin_promotion_code_path(resource), method: :post
  end

  action_item :archive, only: :show, if: proc { !resource.archived? } do
    link_to t("active_admin.promotion_codes.actions.archive"), archive_admin_promotion_code_path(resource), method: :post
  end

  action_item :restore, only: :show, if: proc { resource.archived? } do
    link_to t("active_admin.promotion_codes.actions.restore"), restore_admin_promotion_code_path(resource), method: :post
  end

  index do
    selectable_column
    id_column
    column :code
    column :percent_off
    column :active do |promotion|
      status_tag(promotion.active? ? "active" : "inactive")
    end
    column :archived_at
    column :expires_at
    column :max_redemptions
    column :stripe_coupon_id
    column :stripe_promotion_code_id
    column :updated_at
    actions defaults: true do |promotion|
      if promotion.archived?
        item t("active_admin.promotion_codes.actions.restore"), restore_admin_promotion_code_path(promotion), method: :post
      elsif promotion.active?
        item t("active_admin.promotion_codes.actions.deactivate"), deactivate_admin_promotion_code_path(promotion), method: :post
      else
        item t("active_admin.promotion_codes.actions.activate"), activate_admin_promotion_code_path(promotion), method: :post
      end
    end
  end

  filter :code
  filter :percent_off
  filter :active
  filter :archived_at
  filter :expires_at
  filter :created_at

  show do
    attributes_table do
      row :code
      row :percent_off
      row(:status) { |promotion| promotion.archived? ? status_tag("archived") : status_tag(promotion.active? ? "active" : "inactive") }
      row :expires_at
      row :max_redemptions
      row :stripe_coupon_id
      row :stripe_promotion_code_id
      row :created_at
      row :updated_at
      row :archived_at
    end

    panel t("active_admin.promotion_codes.sections.english_copy") do
      attributes_table_for resource do
        row(:title_en)
        row(:body_en) { |promotion| simple_format(promotion.body_en) }
        row(:cta_label_en)
      end
    end

    panel t("active_admin.promotion_codes.sections.spanish_copy") do
      attributes_table_for resource do
        row(:title_es)
        row(:body_es) { |promotion| simple_format(promotion.body_es) }
        row(:cta_label_es)
      end
    end
  end

  form do |f|
    f.inputs t("active_admin.promotion_codes.sections.details") do
      f.input :code, hint: t("active_admin.promotion_codes.hints.code")
      f.input :percent_off
      f.input :active, hint: t("active_admin.promotion_codes.hints.active")
    end

    f.inputs t("active_admin.promotion_codes.sections.english_copy") do
      f.input :title_en
      f.input :body_en, as: :text, input_html: { rows: 4 }
      f.input :cta_label_en
    end

    f.inputs t("active_admin.promotion_codes.sections.spanish_copy") do
      f.input :title_es
      f.input :body_es, as: :text, input_html: { rows: 4 }
      f.input :cta_label_es
    end

    f.inputs t("active_admin.promotion_codes.sections.advanced") do
      f.input :expires_at,
              as: :string,
              input_html: {
                type: "datetime-local",
                value: f.object.expires_at&.strftime("%Y-%m-%dT%H:%M")
              },
              hint: t("active_admin.promotion_codes.hints.expires_at")
      f.input :max_redemptions, hint: t("active_admin.promotion_codes.hints.max_redemptions")
    end

    if f.object.persisted?
      f.inputs t("active_admin.promotion_codes.sections.stripe") do
        f.input :stripe_coupon_id, input_html: { value: f.object.stripe_coupon_id, disabled: true }
        f.input :stripe_promotion_code_id, input_html: { value: f.object.stripe_promotion_code_id, disabled: true }
      end
    end

    f.actions
  end
end
