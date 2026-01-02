class ExpertAdvisorsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_accessible_expert_advisors
  before_action :set_expert_advisor_entry, only: [:show, :guides, :download]
  before_action :set_guide_preview, only: [:show]
  before_action :ensure_guide_access!, only: [:guides]
  before_action :ensure_download_access!, only: [:download]
  before_action :set_markdown, only: [:guides]

  def index
    @guide_previews = ExpertAdvisors::GuidePreview.for_entries(@accessible_eas, locale: I18n.locale)
  end

  def show; end

  def guides; end

  def download
    unless @expert_advisor.ea_files.attached?
      redirect_back fallback_location: dashboard_expert_advisors_path, alert: t("dashboard.expert_advisors.download_missing")
      return
    end

    @expert_advisor.ensure_bundle_filename!
    redirect_to rails_blob_path(@expert_advisor.ea_files, disposition: "attachment")
  end

  private

  def set_expert_advisor_entry
    @expert_advisor_entry = @accessible_eas.detect { |entry| entry.expert_advisor.ea_id == params[:id] }
    @expert_advisor = @expert_advisor_entry&.expert_advisor || ExpertAdvisor.find_by!(ea_id: params[:id])
  end

  def ensure_guide_access!
    has_license = @expert_advisor_entry&.license.present?
    has_user_ea = current_user.user_expert_advisors.where(expert_advisor_id: @expert_advisor.id).exists?
    head :not_found unless has_license || has_user_ea
  end

  def ensure_download_access!
    return if @expert_advisor_entry&.accessible

    redirect_back fallback_location: dashboard_expert_advisors_path, alert: t("dashboard.expert_advisors.download_locked")
  end

  def set_markdown
    @doc_headings = []
    markdown = @expert_advisor.doc_guide_for(I18n.locale)
    return if markdown.blank?

    rendered = MarkdownRenderer.render(markdown, with_toc: true)
    @markdown_html = rendered[:html]
    @doc_headings = rendered[:headings]
  end

  def set_guide_preview
    @guide_preview = ExpertAdvisors::GuidePreview.call(@expert_advisor.doc_guide_for(I18n.locale))
  end
end
