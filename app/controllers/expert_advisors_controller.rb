class ExpertAdvisorsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!
  before_action :set_user_expert_advisors
  before_action :set_expert_advisor, only: [:docs]
  before_action :set_markdown, only: [:docs]

  def index; end

  def docs; end

  private

  def set_user_expert_advisors
    @user_expert_advisors = current_user.user_expert_advisors.active.includes(:expert_advisor)
  end

  def set_expert_advisor
    @expert_advisor = @user_expert_advisors.find_by!(expert_advisor_id: params[:id]).expert_advisor
  end

  def set_markdown
    docs = @expert_advisor.active_documents.with_indifferent_access
    locale_key = "markdown_#{I18n.locale}"
    fallback_key = "manual_#{I18n.locale}"

    path = docs[locale_key] || docs[fallback_key]
    return unless path&.end_with?(".md")

    absolute = Rails.root.join("public", path.delete_prefix("/"))
    return unless File.exist?(absolute)

    markdown = File.read(absolute)
    @markdown_html = MarkdownRenderer.render(markdown)
  end
end
