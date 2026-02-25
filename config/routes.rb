Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  devise_for :admin_users, ActiveAdmin::Devise.config.merge(
    controllers: { sessions: "admin_users/sessions" }
  )
  ActiveAdmin.routes(self)
  devise_for :users
  namespace :api do
    namespace :v1 do
      get "/", to: "root#index"
      devise_scope :user do
        post "users/sign_in", to: "users/sessions#create", defaults: { format: :json }
        delete "users/sign_out", to: "users/sessions#destroy", defaults: { format: :json }
      end

      # 商家相关 API
      resource :merchant, only: [], controller: 'merchants' do
        get :status
      end

      # 反馈相关 API
      resources :feedbacks, only: [:create, :show] do
        collection do
          get :captcha
        end
      end
    end

    # 支付回调 (Payment Provider Callbacks)
    # Not versioned — callback URLs are registered with providers and must remain stable.
    # POST /api/payments/callbacks/wechat
    # POST /api/payments/callbacks/alipay
    namespace :payments do
      scope :callbacks do
        post :wechat, to: "callbacks#wechat"
        post :alipay, to: "callbacks#alipay"
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end

