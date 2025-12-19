Rails.application.routes.draw do
  # Pay Stripe webhooks (outside locale scope)
  post "/webhooks/stripe", to: "pay/webhooks/stripe#create"

  scope "(:locale)", locale: /en|es/ do
    devise_for :users, controllers: {
      registrations: "users/registrations",
      sessions: "users/sessions",
      passwords: "users/passwords"
    }

    get "dashboard", to: "dashboards#show", as: :dashboard
    get "dashboard/analytics", to: "dashboards#analytics", as: :dashboard_analytics
    get "dashboard/expert_advisors", to: "expert_advisors#index", as: :dashboard_expert_advisors
    get "dashboard/pricing", to: "dashboards#pricing", as: :dashboard_pricing
    get "dashboard/billing", to: "dashboards#billing", as: :dashboard_billing
    get "dashboard/support", to: "dashboards#support", as: :dashboard_support
    get "dashboard/settings", to: "dashboard/settings#show", as: :dashboard_settings
    patch "dashboard/settings", to: "dashboard/settings#update"
    get "dashboard/expert_advisors/:id/docs", to: "expert_advisors#docs", as: :dashboard_expert_advisor_docs
    get "dashboard/expert_advisors/:id/download/:doc_key", to: "expert_advisors#download", as: :dashboard_expert_advisor_download
    post "dashboard/checkout", to: "dashboards#checkout", as: :dashboard_checkout
    post "dashboard/billing_portal", to: "dashboards#billing_portal", as: :dashboard_billing_portal

    get "pricing", to: "pages#pricing"
    get "docs", to: "pages#docs"
    get "terms", to: "legal#terms"
    get "privacy", to: "legal#privacy"
    root "pages#home"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "licenses/verify", to: "licenses#verify"
    end
  end
end
