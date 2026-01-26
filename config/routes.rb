Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config.merge(
    controllers: { sessions: "admin_users/sessions" }
  )
  ActiveAdmin.routes(self)
  devise_for :users
  namespace :api do
    namespace :v1 do
      devise_scope :user do
        post "users/sign_in", to: "api/v1/users/sessions#create", defaults: { format: :json }
        delete "users/sign_out", to: "api/v1/users/sessions#destroy", defaults: { format: :json }
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
