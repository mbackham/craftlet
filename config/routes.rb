Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  devise_for :admin_users, ActiveAdmin::Devise.config.merge(
    controllers: { sessions: "admin_users/sessions" }
  )
  ActiveAdmin.routes(self)
  # devise_for :users — Week 0 改造：移除 :registerable 路由，仅保留密码重置功能
  # App 端用户通过 Logto 注册和登录，不再使用 Devise session 路由。
  # Week 0 refactor: removed :registerable routes; only password reset is kept.
  # App users register and sign in via Logto; Devise session routes are no longer used.
  devise_for :users, only: [:passwords]

  namespace :api do
    namespace :v1 do
      get "/", to: "root#index"

      # ⚠️  Week 0 改造：以下 devise_scope 路由（sign_in / sign_out）已废弃。
      # App 端认证改由 Logto JWT 中间件处理（Week 1 实现）。
      # ⚠️  Week 0 refactor: the devise_scope sign_in/sign_out routes below are deprecated.
      # App authentication is now handled by the Logto JWT middleware (implemented in Week 1).
      # devise_scope :user do
      #   post "users/sign_in",  to: "users/sessions#create",  defaults: { format: :json }
      #   delete "users/sign_out", to: "users/sessions#destroy", defaults: { format: :json }
      # end

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

      # 内容运营 API (公开只读)
      resources :banners, only: [:index]
      resources :announcements, only: [:index]
      resources :faqs, only: [:index]

      # 营销工具 API (需登录)
      resources :coupons, only: [:index] do
        collection do
          get  :available
          post :redeem
          post :grant_new_user
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

    # Logto Webhook (HMAC-SHA256 verified, no JWT auth)
    # POST /api/webhooks/logto
    namespace :webhooks do
      post :logto, to: "logto#receive"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end

