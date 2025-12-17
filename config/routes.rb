Rails.application.routes.draw do
  scope "(:locale)", locale: /en|es/ do
    devise_for :users, controllers: {
      registrations: "users/registrations",
      sessions: "users/sessions",
      passwords: "users/passwords"
    }

    get "dashboard", to: "dashboards#show", as: :dashboard
    get "dashboard/analytics", to: "dashboards#analytics", as: :dashboard_analytics
    get "dashboard/pricing", to: "dashboards#pricing", as: :dashboard_pricing
    get "dashboard/billing", to: "dashboards#billing", as: :dashboard_billing
    get "dashboard/support", to: "dashboards#support", as: :dashboard_support
    get "dashboard/expert_advisors/:id/docs", to: "expert_advisors#docs", as: :dashboard_expert_advisor_docs

    get "pricing", to: "pages#pricing"
    get "docs", to: "pages#docs"
    root "pages#home"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
