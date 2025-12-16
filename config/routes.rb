Rails.application.routes.draw do
  scope "(:locale)", locale: /en|es/ do
    devise_for :users, controllers: { registrations: "users/registrations" }

    resource :dashboard, only: :show, controller: "dashboards"
    get "pricing", to: "pages#pricing"
    get "docs", to: "pages#docs"
    root "pages#home"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
