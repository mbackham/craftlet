# frozen_string_literal: true

module Api
  module V1
    class CouponsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/coupons
      # Returns the current user's coupons
      def index
        coupons = current_user_coupons.order(granted_at: :desc)
        coupons = coupons.where(status: params[:status]) if params[:status].present?

        render json: coupons.map { |c| coupon_json(c) }
      end

      # GET /api/v1/coupons/available
      # Returns usable coupons optionally filtered by order amount
      def available
        coupons = current_user_coupons.valid
        if params[:order_amount].present?
          amount = params[:order_amount].to_d
          coupons = coupons.select { |c| c.coupon_template.min_order_amount <= amount }
        end
        render json: coupons.map { |c| coupon_json(c) }
      end

      # POST /api/v1/coupons/redeem
      # Redeem a coupon template by code (for redeem_code type coupons)
      def redeem
        code = params[:code].to_s.strip.upcase
        return render json: { error: I18n.t("api.coupons.code_required") }, status: :unprocessable_entity if code.blank?

        # Find template by matching a specific redeem_code-type template
        tmpl = CouponTemplate.active.where(coupon_type: "redeem_code").first
        if tmpl.nil?
          return render json: { error: I18n.t("api.coupons.invalid_code") }, status: :unprocessable_entity
        end

        coupon = tmpl.issue_to!(current_user, grant_type: "redeem")
        render json: coupon_json(coupon), status: :created
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/coupons/grant_new_user
      # Grant new-user coupons (called on user registration)
      def grant_new_user
        templates = CouponTemplate.active.where("grant_rules @> ?", { new_user: true }.to_json)
        granted = templates.filter_map do |tmpl|
          tmpl.issue_to!(current_user, grant_type: "new_user")
        rescue StandardError
          nil
        end
        render json: granted.map { |c| coupon_json(c) }, status: :created
      end

      private

      def current_user_coupons
        Coupon.where(user_id: current_user.id).includes(:coupon_template)
      end

      def coupon_json(coupon)
        tmpl = coupon.coupon_template
        {
          id:          coupon.id,
          code:        coupon.code,
          status:      coupon.status,
          grant_type:  coupon.grant_type,
          granted_at:  coupon.granted_at,
          expires_at:  coupon.expires_at,
          used_at:     coupon.used_at,
          usable:      coupon.usable?,
          template: {
            id:               tmpl.id,
            name:             tmpl.name,
            coupon_type:      tmpl.coupon_type,
            face_value:       tmpl.face_value,
            min_order_amount: tmpl.min_order_amount
          }
        }
      end
    end
  end
end
