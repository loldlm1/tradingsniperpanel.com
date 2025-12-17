Rails.application.routes.draw do
  mount Pay::Engine => "/pay", as: "pay_engine"

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
    post "dashboard/checkout", to: "dashboards#checkout", as: :dashboard_checkout
    post "dashboard/billing_portal", to: "dashboards#billing_portal", as: :dashboard_billing_portal

    get "pricing", to: "pages#pricing"
    get "docs", to: "pages#docs"
    root "pages#home"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
