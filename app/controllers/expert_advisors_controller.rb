class ExpertAdvisorsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_accessible_expert_advisors
  before_action :set_expert_advisor_entry, only: [:docs, :download]
  before_action :ensure_access!, only: [:docs]
  before_action :set_markdown, only: [:docs]

  def index; end

  def docs; end

  def download
    docs = @expert_advisor.active_documents.with_indifferent_access
    path = docs[params[:doc_key]]
    return redirect_back fallback_location: dashboard_expert_advisors_path, alert: t("dashboard.expert_advisors.download_missing", default: "Document not found") if path.blank?

    absolute = Rails.root.join(path)
    docs_root = Rails.root.join("docs_eas")
    docs_root = docs_root.realpath if docs_root.exist?
    file_real = absolute.realpath
    unless file_real.to_s.start_with?(docs_root.to_s)
      redirect_back(fallback_location: dashboard_expert_advisors_path, alert: t("dashboard.expert_advisors.download_missing", default: "Document not found")) and return
    end

    send_file file_real, disposition: "inline"
  rescue Errno::ENOENT
    redirect_back fallback_location: dashboard_expert_advisors_path, alert: t("dashboard.expert_advisors.download_missing", default: "Document not found")
  end

  private

  def set_expert_advisor_entry
    @expert_advisor_entry = @accessible_eas.detect { |entry| entry.expert_advisor.ea_id == params[:id] }
    @expert_advisor = @expert_advisor_entry&.expert_advisor || ExpertAdvisor.find_by!(ea_id: params[:id])
  end

  def ensure_access!
    has_license = @expert_advisor_entry&.license.present?
    has_user_ea = current_user.user_expert_advisors.where(expert_advisor_id: @expert_advisor.id).exists?
    head :not_found unless has_license || has_user_ea
  end

  def set_markdown
    @doc_headings = []
    docs = @expert_advisor.active_documents.with_indifferent_access
    locale_key = "markdown_#{I18n.locale}"
    fallback_key = "manual_#{I18n.locale}"

    path = docs[locale_key] || docs[fallback_key]
    return unless path&.end_with?(".md")

    absolute = Rails.root.join(path.delete_prefix("/"))
    unless File.exist?(absolute)
      fallback_docs = Rails.root.join("docs_eas", path.delete_prefix("/docs/"))
      absolute = fallback_docs if File.exist?(fallback_docs)
    end
    return unless File.exist?(absolute)

    markdown = File.read(absolute)
    rendered = MarkdownRenderer.render(markdown, with_toc: true)
    @markdown_html = rendered[:html]
    @doc_headings = rendered[:headings]
  end
end
