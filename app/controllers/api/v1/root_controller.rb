# frozen_string_literal: true

module Api
  module V1
    class RootController < BaseController
      def index
        render json: {
          name: "Craftlet API",
          version: "v1",
          endpoints: {
            sign_in: { method: "POST", path: "/api/v1/users/sign_in" },
            sign_out: { method: "DELETE", path: "/api/v1/users/sign_out" },
            merchant_status: { method: "GET", path: "/api/v1/merchant/status" },
            feedbacks_create: { method: "POST", path: "/api/v1/feedbacks" },
            feedbacks_show: { method: "GET", path: "/api/v1/feedbacks/:id" },
            feedbacks_captcha: { method: "GET", path: "/api/v1/feedbacks/captcha" }
          }
        }
      end
    end
  end
end
