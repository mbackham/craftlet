# frozen_string_literal: true

module Api
  module V1
    class MerchantsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/merchant/status
      # 返回当前用户的商家审核状态
      def status
        merchant_profile = current_user.merchant_profile

        if merchant_profile.nil?
          render json: {
            status: 'not_applied',
            message: '您尚未申请入驻'
          }
        else
          render json: {
            status: merchant_profile.status,
            shop_name: merchant_profile.shop_name,
            message: status_message(merchant_profile),
            rejected_reason: merchant_profile.reject_reason,
            approved_at: merchant_profile.approved_at&.iso8601,
            rejected_at: merchant_profile.rejected_at&.iso8601,
            created_at: merchant_profile.created_at&.iso8601
          }
        end
      end

      private

      def status_message(profile)
        case profile.status
        when 'pending'
          '您的资料尚未提交审核'
        when 'submitted'
          '您的资料正在审核中，请耐心等待'
        when 'approved'
          '恭喜！您的商家入驻申请已通过'
        when 'rejected'
          '很抱歉，您的申请未通过审核'
        when 'suspended'
          '您的商家账户已被停用'
        else
          ''
        end
      end
    end
  end
end
