module Api
  module V1
    module Users
      class SessionsController < Devise::SessionsController
        respond_to :json
        skip_before_action :verify_authenticity_token, raise: false

        private

        def respond_with(resource, _opts = {})
          token = request.env["warden-jwt_auth.token"]
          render json: {
            user: { id: resource.id, email: resource.email },
            token: token
          }, status: :ok
        end

        def respond_to_on_destroy
          head :no_content
        end
      end
    end
  end
end
