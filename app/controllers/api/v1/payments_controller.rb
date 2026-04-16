# frozen_string_literal: true

# app/controllers/api/v1/payments_controller.rb
#
# POST /api/v1/payments          → 创建支付单（返回 App 调起支付所需参数）
# GET  /api/v1/payments/:id/status → 查询支付状态
#
module Api
  module V1
    class PaymentsController < BaseController
      # POST /api/v1/payments
      def create
        order = Order.find(params[:order_id])

        # 确认是订单的消费者
        unless order.customer_id == Order.id_to_uuid(current_user.id)
          return render_forbidden
        end

        # 确认订单状态为 created（待支付）
        unless order.created?
          return render_error(
            message: I18n.t('api.errors.payment.invalid_order_status'),
            code: 'invalid_order_status',
            status: :unprocessable_entity
          )
        end

        channel = params[:channel].to_s
        unless %w[wechat alipay].include?(channel)
          return render_error(
            message: I18n.t('api.errors.payment.unsupported_channel'),
            code: 'unsupported_channel',
            status: :unprocessable_entity
          )
        end

        service = ::Payments::CreatePaymentService.new(order: order, channel: channel)
        service.call

        if service.success?
          payment = service.payment
          render_success(
            data: {
              payment_id: payment.id,
              channel: payment.channel,
              status: payment.status,
              amount: payment.amount.to_s,
              currency: payment.currency,
              idempotency_key: payment.idempotency_key,
              pay_params: payment.response_payload
            },
            status: :created
          )
        else
          render_error(
            message: service.error || I18n.t('api.errors.payment.create_failed'),
            code: 'payment_create_failed',
            status: :unprocessable_entity
          )
        end
      end

      # GET /api/v1/payments/:id/status
      def status
        payment = Payment.find(params[:id])

        # 验证当前用户是否为订单消费者
        unless payment.order.customer_id == Order.id_to_uuid(current_user.id)
          return render_forbidden
        end

        render_success(
          data: PaymentBlueprint.render_as_hash(payment)
        )
      end
    end
  end
end
