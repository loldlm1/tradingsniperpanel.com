Rails.application.routes.draw do
  get "/sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  get "/robots.txt", to: "sitemaps#robots", defaults: { format: :text }

  ActiveAdmin.routes(self)
  # Pay Stripe webhooks (outside locale scope)
  post "/webhooks/stripe", to: "pay/webhooks/stripe#create"

  devise_for :users, only: :omniauth_callbacks, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  scope "(:locale)", locale: /en|es/ do
    devise_for :users, controllers: {
      registrations: "users/registrations",
      sessions: "users/sessions",
      passwords: "users/passwords"
    }, skip: [:omniauth_callbacks]

    get "dashboard", to: "dashboards#show", as: :dashboard
    get "dashboard/analytics", to: "dashboards#analytics", as: :dashboard_analytics
    get "dashboard/expert_advisors", to: "expert_advisors#index", as: :dashboard_expert_advisors
    get "dashboard/courses", to: "courses#index", as: :dashboard_courses
    get "dashboard/marketplace", to: "marketplace#index", as: :dashboard_marketplace
    get "dashboard/marketplace/assets/:id", to: "marketplace_assets#show", as: :dashboard_marketplace_asset
    get "dashboard/marketplace/assets/:id/download", to: "marketplace_assets#download", as: :dashboard_marketplace_asset_download
    get "dashboard/marketplace/:id", to: "marketplace#show", as: :dashboard_marketplace_product
    post "dashboard/marketplace/:id/checkout", to: "marketplace#checkout", as: :dashboard_marketplace_product_checkout
    get "dashboard/plans", to: "dashboards#plans", as: :dashboard_plans
    get "dashboard/billing", to: "dashboards#billing", as: :dashboard_billing
    get "dashboard/support", to: "dashboards#support", as: :dashboard_support
    post "dashboard/support", to: "dashboards#create_support_request"
    get "dashboard/settings", to: "dashboard/settings#show", as: :dashboard_settings
    patch "dashboard/settings", to: "dashboard/settings#update"
    get "dashboard/expert_advisors/:id", to: "expert_advisors#show", as: :dashboard_expert_advisor
    get "dashboard/expert_advisors/:id/guides", to: "expert_advisors#guides", as: :dashboard_expert_advisor_guides
    get "dashboard/expert_advisors/:id/addons/:addon_key/guide", to: "expert_advisors#addon_guide", as: :dashboard_expert_advisor_addon_guide
    get "dashboard/expert_advisors/:id/download", to: "expert_advisors#download", as: :dashboard_expert_advisor_download
    get "dashboard/courses/:id", to: "courses#show", as: :dashboard_course
    get "dashboard/courses/:course_id/lessons/:id", to: "course_lessons#show", as: :dashboard_course_lesson
    patch "dashboard/courses/:course_id/lessons/:id/progress", to: "course_lessons#update_progress", as: :dashboard_course_lesson_progress
    post "dashboard/product_releases/:id/dismiss", to: "dashboard/product_releases#dismiss", as: :dismiss_dashboard_product_release
    post "dashboard/checkout", to: "dashboards#checkout", as: :dashboard_checkout
    post "dashboard/plans/cancel", to: "dashboards#cancel_scheduled_downgrade", as: :dashboard_cancel_scheduled_downgrade
    post "dashboard/billing/cancel", to: "dashboards#cancel_subscription", as: :dashboard_cancel_subscription
    post "dashboard/billing/resume", to: "dashboards#resume_subscription", as: :dashboard_resume_subscription
    post "dashboard/billing_portal", to: "dashboards#billing_portal", as: :dashboard_billing_portal
    resource :dashboard_partner, only: [:show], path: "dashboard/partner", controller: "dashboard/partner" do
      post :request_payout
    end

    resource :terms_acceptance, only: [:new, :create]

    get "terms", to: "legal#terms"
    get "privacy", to: "legal#privacy"
    get "refunds-and-cancellations", to: "legal#refunds_and_cancellations"
    root "pages#home"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "licenses/verify", to: "licenses#verify"
      post "licenses/heartbeat", to: "licenses#heartbeat"
      post "broker_accounts/daily_results", to: "broker_account_daily_results#create"
    end
  end
end
